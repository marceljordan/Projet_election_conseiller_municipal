# Projet fil rouge — Élus municipaux 2026

Mastère 1 IA & Data · Ingénierie des données & pipelines SQL

## 1. Sujet

**Profil des conseillers municipaux élus en mars 2026.**

Question métier : les conseils municipaux issus des élections de mars 2026 sont-ils représentatifs, et l'accès aux fonctions exécutives (maire, adjoint) est-il aussi équilibré que l'accès au mandat de conseiller ?

Axes d'analyse :
- **Parité** : part des femmes selon la fonction (conseiller, adjoint, maire)
- **Âge** : âge au début du mandat selon la catégorie socio-professionnelle et le sexe
- **Catégories socio-professionnelles** : poids des retraités, des cadres, des agriculteurs…
- **Territoire** : écarts entre départements et types de territoire
- **Temps** : rythme des prises de fonction après les deux tours (15 et 22 mars 2026)

## 2. Source et licence

| Élément | Valeur |
|---|---|
| Jeu de données | Répertoire national des élus (RNE) |
| Producteur | Ministère de l'Intérieur |
| Lien | https://www.data.gouv.fr/datasets/repertoire-national-des-elus-1 |
| Licence | Licence Ouverte / Open Licence 2.0 (Etalab) |
| Mise à jour | Trimestrielle |
| Fichier utilisé | `elus-conseiller-municipal-cm.csv` (conseillers municipaux) |
| Volume source | 510 195 lignes, 16 colonnes |

Le fichier CSV n'est pas versionné dans ce dépôt (65 Mo, données nominatives). Il est téléchargeable à l'adresse ci-dessus.

## 3. Environnement

- **SGBD** : PostgreSQL hébergé sur **Supabase** (base partagée par le groupe)
- **Client SQL** : DBeaver
- **Visualisation** : Power BI
- **Versionnement** : Git / GitHub

## 4. Architecture des données (médaillon)

| Couche | Schéma | Contenu |
|---|---|---|
| Bronze | `bronze` | Données brutes importées telles quelles depuis le CSV (`bronze_conseillers_municipal`) |
| Silver | `silver` | Données nettoyées, typées et dédoublonnées (`conseillers_municipaux`) |
| Gold | `gold` | Modèle en étoile pour l'analyse |

## 5. Nettoyage (bronze → silver)

Le bronze n'est jamais modifié : le nettoyage est appliqué lors de la création du silver.

- **Typage maîtrisé** : conversion de toutes les colonnes en texte, puis typage explicite des dates ; rétablissement des zéros de tête des codes commune et département
- **Standardisation** : renommage des colonnes, suppression des espaces, chaînes vides → NULL
- **Valeurs manquantes** :
  - département absent (3 530 lignes d'outre-mer) → déduit du code commune
  - fonction absente (356 627 lignes) → « Conseiller municipal » (simple conseiller, pas une donnée manquante)
  - nom « NA » conservé : c'est un vrai nom, pas une valeur manquante
- **Doublons** : aucun doublon exact. Sur 731 identités (nom, prénom, date de naissance) répétées :
  - 711 cumuls de fonctions dans une même commune → conservés
  - 1 vrai doublon → seule la ligne la plus récente est gardée
  - 19 identités dans des communes différentes → conservées et signalées (`flag_homonyme`)
- **Valeurs aberrantes** : 10 dates de naissance antérieures à 1910 (valeurs par défaut 01/01/1900, fautes de saisie) → NULL et signalées (`flag_naissance_aberrante`)

Résultat : 510 195 lignes en bronze → 510 194 lignes en silver (1 ligne retirée).

Encodage : 2 libellés de fonction (« 2ème » et « 8ème adjoint ») ont été corrompus à l'import (« è » → « �� »). Le fichier source est sain : le bronze conserve la valeur brute, la correction est appliquée dans le silver et le gold.

## 6. Schéma en étoile (gold)

```
                     dim_date
                         |
dim_cat_socio_prof — fact_mandat_fonction — dim_elu
                    /                     \
            dim_commune               dim_fonction
```

| Table | Clé primaire | Contenu |
|---|---|---|
| `fact_mandat_fonction` | (`sk_date_snapshot`, `sk_elu`, `sk_commune`, `sk_fonction`) | 1 ligne = 1 élu exerçant 1 fonction dans 1 commune. Mesures : `nb_mandat`, `age_debut_mandat` |
| `dim_elu` | `sk_elu` | Nom, prénom, sexe, date et année de naissance, nationalité |
| `dim_commune` | `sk_commune` | Commune, département, collectivité, type de territoire |
| `dim_fonction` | `sk_fonction` | Libellé, type de fonction, rang d'adjoint, exécutif ou non |
| `dim_cat_socio_prof` | `sk_csp` | Catégorie socio-professionnelle et groupe |
| `dim_date` | `sk_date` | Date, jour, mois, trimestre, année, week-end |

Clés étrangères de la table de faits : `sk_elu`, `sk_commune`, `sk_fonction`, `sk_csp`, et trois liens vers `dim_date` (`sk_date_snapshot`, `sk_date_debut_mandat`, `sk_date_debut_fonction`).

Schéma relationnel : `docs/schema_relationnel.png`

## 7. Les 6 critères

| Critère | Mise en œuvre |
|---|---|
| Tables reliées | 1 table de faits et 5 dimensions reliées par clés primaires et étrangères |
| Dates | Dates de début de mandat, de début de fonction et d'extraction, reliées à `dim_date` |
| Catégories | Sexe, nationalité, catégorie socio-professionnelle, type de fonction, type de territoire |
| Hiérarchies | Commune → département ; CSP → groupe CSP ; fonction → type de fonction ; jour → mois → trimestre → année |
| Volume | 510 195 lignes source, passage à environ 10 M lignes prévu (jalon 2) |
| Licence | Licence Ouverte / Open Licence 2.0 |

## 8. Arborescence du dépôt

```
Projet_election_conseiller_municipal/
├── README.md
├── sql/
│   ├── SilverCreation.sql      nettoyage et création du silver
│   ├── SilverControle.sql      contrôles qualité du silver
│   └── Nettoyage_slicer.sql    diagnostic qualité du bronze
└── docs/
    └── schema_relationnel.png  (à ajouter)
```

## 9. Avancement

- [x] Choix du sujet et du jeu de données
- [x] Import des données brutes (bronze)
- [x] Nettoyage, dédoublonnage et contrôles (silver)
- [x] Modèle en étoile (gold)
- [ ] Génération du volume à environ 10 M lignes (`01_generation_volume.sql`)
- [ ] Requêtes SQL avancées : classement, LAG/LEAD, NTILE, fenêtre glissante, CTE récursive, CTE enchaînées (`02_requetes_avancees.sql`)
- [ ] Index et benchmark avant / après (`03_index.sql`, `docs/rapport_performance.md`)
- [ ] Tableau de bord Power BI
- [ ] Installation de dbt

## 10. Difficultés rencontrées

- **Types devinés à l'import** : DBeaver a typé certaines colonnes en numérique (erreur `btrim(bigint)`), d'où la conversion explicite en texte avant nettoyage.
- **Faux doublons** : la plupart des identités répétées sont des cumuls de fonctions légitimes, pas des erreurs.
- **Valeurs aberrantes** : dates de naissance par défaut ou mal saisies, neutralisées plutôt que supprimées.
