# dbt — Élus municipaux 2026

Projet dbt qui transforme les données brutes du **Répertoire national des élus** (conseillers municipaux, mars 2026) en un **modèle en étoile** prêt pour l'analyse dans Power BI.

Il reprend en dbt le nettoyage silver et le modèle gold des scripts SQL du dossier [`../sql/`](../sql/), pour obtenir un pipeline **reproductible, testé et documenté**.

## Architecture

```
source  bronze.conseillers_municipaux          CSV brut chargé tel quel
   │
   ▼
staging       stg_conseillers_municipaux            schéma silver · vue
   │
   ▼
intermediate  int_conseillers_municipaux_territoire schéma silver · table
   │
   ├──► dim_elu
   ├──► dim_commune
   ├──► dim_fonction
   ├──► dim_cat_socio_prof
   ├──► dim_date
   └──► fact_mandat_fonction                       schéma gold · tables
```

| Couche | Schéma | Matérialisation | Rôle |
|---|---|---|---|
| `staging` | `silver` | vue | Renommage des colonnes, `trim`, chaînes vides → `NULL`, typage des dates |
| `intermediate` | `silver` | table | Correction du territoire, dédoublonnage |
| `marts` | `gold` | table | Dimensions et table de faits du modèle en étoile |

La macro [`generate_schema_name`](macros/generate_schema_name.sql) écrit les modèles directement dans les schémas `silver` et `gold`, au lieu de les préfixer par le schéma cible (`<target>_silver`, comportement par défaut de dbt).

## Modèles

### Staging — `stg_conseillers_municipaux`

Grain de la source : 1 ligne = 1 élu dans 1 commune.

- Colonnes renommées en `snake_case` (`"Code de la commune"` → `code_commune`, etc.)
- Espaces supprimés, chaînes vides converties en `NULL`
- Dates de naissance, de début de mandat et de début de fonction typées en `date`

### Intermediate — `int_conseillers_municipaux_territoire`

- **Département déduit** : s'il manque, il est déduit des 2 premiers caractères du code commune, hors collectivités à statut particulier et hors outre-mer (`97`, `98`). La colonne `est_departement_deduit` signale ces lignes.
- **Territoire unifié** : `code_territoire` / `libelle_territoire` = département, ou à défaut collectivité à statut particulier.
- **Dédoublonnage** : sur (nom, prénom, date de naissance, sexe, commune, fonction), seule la ligne au début de mandat le plus récent est conservée.

### Marts — modèle en étoile

```
                   dim_date
                      │
dim_cat_socio_prof ── fact_mandat_fonction ── dim_elu
                     /                    \
              dim_commune             dim_fonction
```

| Modèle | Clé | Contenu |
|---|---|---|
| `fact_mandat_fonction` | (`elu_sk`, `commune_sk`, `fonction_sk`) | 1 ligne = 1 élu × 1 commune × 1 fonction. Fait sans mesure : on compte les lignes. |
| `dim_elu` | `elu_sk` | Nom, prénom, date de naissance, sexe, nationalité |
| `dim_commune` | `commune_sk` | Commune, département, collectivité à statut particulier, territoire |
| `dim_fonction` | `fonction_sk` | Libellé de la fonction, plus un membre `-1` « Sans fonction » pour les simples conseillers |
| `dim_cat_socio_prof` | `cat_socio_prof_sk` | Code et libellé de la catégorie socio-professionnelle |
| `dim_date` | `date_sk` (`AAAAMMJJ`) | 1 jour par ligne de 2020 à 2032, plus un membre `-1` pour les dates inconnues |

La table de faits pointe deux fois vers `dim_date` : `date_debut_mandat_sk` et `date_debut_fonction_sk` (`-1` si pas de fonction).

Les clés de substitution sont générées par `dbt_utils.generate_surrogate_key` (hash MD5 des colonnes de la clé naturelle).

> **Limite de la source** : le RNE ne fournit aucun identifiant d'élu. La clé naturelle de `dim_elu` est donc nom + prénom + date de naissance + sexe, ce qui fusionne deux homonymes parfaits (19 cas dans des communes différentes).

## Tests

| Modèle | Tests |
|---|---|
| `stg_conseillers_municipaux` | `not_null` sur commune, nom, prénom, date de naissance, CSP, début de mandat · `accepted_values` `M` / `F` sur le sexe |
| `int_conseillers_municipaux_territoire` | `not_null` sur le territoire ; sur le département hors collectivités à statut particulier |
| Dimensions | `unique` + `not_null` sur chaque clé |
| `fact_mandat_fonction` | `relationships` vers chaque dimension · unicité du grain (`dbt_utils.unique_combination_of_columns`) |

## Installation et exécution

### Prérequis

- Python 3.9 ou plus
- Accès à la base PostgreSQL (Supabase) contenant la table `bronze.conseillers_municipaux`

### 1. Installer dbt

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux / macOS : source .venv/bin/activate)
pip install dbt-postgres
```

### 2. Configurer la connexion

Créer `~/.dbt/profiles.yml` (**ne jamais le versionner**, il contient le mot de passe) :

```yaml
dbt_election_sql:
  target: dev
  outputs:
    dev:
      type: postgres
      host: <hôte Supabase>
      port: 5432
      user: <utilisateur>
      password: "{{ env_var('DBT_PASSWORD') }}"
      dbname: postgres
      schema: silver
      threads: 4
```

### 3. Lancer le pipeline

```bash
cd dbt
dbt deps          # installe dbt_utils
dbt debug         # vérifie la connexion
dbt build         # construit tous les modèles et lance les tests
```

Commandes utiles :

```bash
dbt run --select staging            # une seule couche
dbt run --select +fact_mandat_fonction   # un modèle et tout ce dont il dépend
dbt test                            # tests uniquement
dbt docs generate && dbt docs serve # documentation et graphe de lignage
```

## À savoir

- La source attendue est `bronze.conseillers_municipaux` (déclarée dans [`models/staging/source_csv/conseillers_municipaux.yml`](models/staging/source_csv/conseillers_municipaux.yml)). Adapter ce fichier si la table brute porte un autre nom.
- Les marts sont écrits dans le schéma `gold` avec les mêmes noms de tables que le modèle construit à la main ([`../sql/etoile.sql`](../sql/etoile.sql)). Un `dbt run` les **remplace**. Les noms de clés diffèrent (`elu_sk` côté dbt, `sk_elu` côté SQL) : penser à mettre à jour les requêtes et le rapport Power BI si on bascule sur la version dbt.
- `target/`, `logs/` et `dbt_packages/` sont générés par dbt et ignorés par Git.
