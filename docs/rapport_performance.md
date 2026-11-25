# Rapport de performance — Projet fil rouge « Élus municipaux 2026 »

## 1. Contexte et méthode

- **Base** : PostgreSQL 18 en local, base `projet_fil_rouge`, schéma `gold` (modèle en étoile).
- **Volume** : `fact_mandat_fonction` ≈ **10 M de lignes** (9 999 999), `dim_elu` ≈ 10 M, `dim_commune` ≈ 35 000.
- **Un seul snapshot** : le filtre `sk_date_snapshot = MAX(...)` garde toutes les lignes.
- **Données fictives** : le volume a été obtenu en générant des élus fictifs (685 701 « maires » pour ≈ 35 000 communes). Les temps sont valables pour l'analyse de performance, pas pour des conclusions métier.
- **Mesure** : `EXPLAIN (ANALYZE, BUFFERS)`, 3 passages par configuration, médiane retenue. Les temps varient selon le cache (`shared hit`) et le disque (`read`).

## 2. Benchmark 1 — agrégation sur 10 M de lignes (réglage `work_mem`)

**Requête A** (regroupement par élu) : `SELECT sk_elu, COUNT(*) ... GROUP BY sk_elu ORDER BY nb DESC LIMIT 100`.

| | work_mem = 4 Mo | work_mem = 512 Mo |
|---|---|---|
| Opérateur | HashAggregate | HashAggregate |
| Lots (batches) | 129 | 1 |
| Mémoire utilisée | 9 241 Ko | 655 385 Ko |
| Disque temporaire | 384 424 Ko | aucun |
| Temps (1 passage) | 12 898 ms | 10 463 ms |

Gain faible (×1,23, à confirmer par la médiane de 3 passages) : le débordement sur disque disparaît, mais le hachage de ≈ 10 M de groupes (presque tous les `sk_elu` sont uniques) reste coûteux. Ce n'est **pas un index** : c'est un réglage de session (`SET work_mem`, à remettre avec `RESET work_mem`).

**Requête B** (départements à plus de 150 000 élus, `COUNT(DISTINCT sk_elu)`) :
- Avant : **58 809 ms** ; `Sort Method: external merge Disk: 277 688 kB` (≈ 85 % du temps), `Seq Scan` de la table de faits seulement 1,7 s.
- Après `SET work_mem = '512MB'` : **à mesurer** (attendu : `quicksort Memory`).
- Un index n'aide pas ici : la requête a besoin de toutes les lignes.

## 3. Benchmark 2 — élus d'un département (filtre sélectif)

Requête : élus et âge moyen du département 93 (≈ 31 000 lignes sur 10 M). Index : `idx_fact_sk_commune` sur `fact_mandat_fonction (sk_commune)` (68 Mo, créé en 6-7 s).

| | Passage 1 | Passage 2 | Passage 3 | Médiane |
|---|---|---|---|---|
| Sans index (`Parallel Seq Scan`) | 1 134 ms | 1 072 ms | 968 ms | **1 072 ms** |
| Avec index (`Bitmap Index Scan`) | 409 ms | 406 ms | 337 ms | **406 ms** |

- Gain ×2,6 ; pages lues : 81 536 → ≈ 31 300.
- Gain modéré : les 31 021 lignes du 93 sont **dispersées** sur 30 870 blocs (accès quasi aléatoire). Un premier passage « avec index » à froid a atteint 534 ms.
- Réserve : le passage 3 « sans index » (968 ms) date du début de la session.
- Piste complémentaire : index couvrant `(sk_commune) INCLUDE (sk_elu, age_debut_mandat)` pour obtenir un `Index Only Scan` (non mesuré).

## 4. Benchmark 3 — parité des maires par département (3 jointures)

Requête : part de femmes parmi les maires par département (jointures `dim_elu`, `dim_fonction`, `dim_commune`).

| | Plan sur `dim_elu` | Temps | Pages lues sur disque |
|---|---|---|---|
| Avant | `Nested Loop` + `dim_elu_pkey` (685 701 recherches) | **21 678 ms** (1 passage à froid) | 1 229 742 |
| Après `idx_elu_couvrant` | `Index Only Scan`, `Heap Fetches: 0` | **4 273 ms** (1 passage) | 367 598 |

- Gain ×5. Index : `idx_elu_couvrant` sur `dim_elu (sk_elu) INCLUDE (code_sexe)` (214 Mo).
- **Index testé sans effet** : `idx_fact_sk_fonction` sur `fact_mandat_fonction (sk_fonction)`. Le `Parallel Seq Scan` de la table de faits ne représente que ≈ 1 s sur 21 s ; le vrai goulot est l'accès à `dim_elu`. L'index n'est pas utilisé et a été supprimé. Un index inutilisé reste un résultat valable.
- Le moteur a sous-estimé le nombre de maires (101 628 prévus pour 228 567 réels par worker) et a choisi des lectures une par une.
- À compléter : médiane de 3 passages avant et après (les mesures actuelles sont des passages uniques).

## 5. Conclusion

| Benchmark | Levier | Avant | Après | Gain |
|---|---|---|---|---|
| 1 | `work_mem` (réglage) | 12 898 ms | 10 463 ms | ×1,2 |
| 2 | Index `sk_commune` | 1 072 ms | 406 ms | ×2,6 |
| 3 | Index couvrant `dim_elu` | 21 678 ms | 4 273 ms | ×5 |

Un index sert quand la requête est **sélective** (benchmark 2) ou quand il évite des milliers d'accès à la table (benchmark 3). Il ne sert pas quand la requête doit lire toutes les lignes (benchmark 1) : il faut alors agir sur la mémoire.
