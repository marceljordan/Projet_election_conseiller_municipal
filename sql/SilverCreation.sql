--- ------------------------------------ creation du  silver  avec  de donnnées  nettoyer  propre a l'exploitaton
----------------------------Les dates de naissance aberrantes sont soit des valeurs par défaut (01/01/1900), soit des fautes de saisie.
-------------------------- Plutôt que de supprimer des mandats valides ou d'inventer une date, nous avons remplacé la date par NULL et ajouté un indicateur de qualité.
------------------------ Ces élus restent comptés dans les effectifs, mais sont exclus des calculs d'âge. 
DROP SCHEMA IF EXISTS silver CASCADE;
CREATE SCHEMA silver;

-- 3.1 Renommage, conversion en texte, suppression des espaces, vides -> NULL, fonction vide -> Conseiller municipal
CREATE TABLE silver.tmp_conseillers AS
SELECT LPAD(NULLIF(TRIM("Code du département"::text), ''), 2, '0')                AS code_dep,
       NULLIF(TRIM("Libellé du département"::text), '')                             AS lib_dep,
       NULLIF(TRIM("Libellé de la collectivité à statut particulier"::text), '')    AS lib_csp_part,
       LPAD(NULLIF(TRIM("Code de la commune"::text), ''), 5, '0')                   AS code_commune,
       NULLIF(TRIM("Libellé de la commune"::text), '')                              AS lib_commune,
       TRIM("Nom de l'élu"::text)                                                   AS nom,
       NULLIF(TRIM("Prénom de l'élu"::text), '')                                    AS prenom,
       NULLIF(TRIM("Code sexe"::text), '')                                          AS sexe,
       NULLIF(TRIM("Date de naissance"::text), '')                                  AS date_naissance,
       NULLIF(TRIM("Code de la catégorie socio-professionnelle"::text), '')         AS code_csp,
       NULLIF(TRIM("Libellé de la catégorie socio-professionnelle"::text), '')      AS lib_csp,
       NULLIF(TRIM("Date de début du mandat"::text), '')                            AS date_debut_mandat,
       COALESCE(NULLIF(TRIM("Libellé de la fonction"::text), ''), 'Conseiller municipal') AS lib_fonction,
       NULLIF(TRIM("Date de début de la fonction"::text), '')                       AS date_debut_fonction,
       NULLIF(TRIM("Code nationalité"::text), '')                                   AS nationalite
FROM bronze.bronze_conseillers_municipal;

-- 3.2 Silver : dédoublonnage, typage
CREATE TABLE silver.conseillers_municipaux AS
WITH dedoublonne AS (
    SELECT t.*,
           ROW_NUMBER() OVER (PARTITION BY nom, prenom, date_naissance, code_commune, lib_fonction
                              ORDER BY date_debut_mandat DESC) AS rang
    FROM silver.tmp_conseillers t
),
homonymes AS (
    SELECT nom, prenom, date_naissance
    FROM silver.tmp_conseillers
    GROUP BY nom, prenom, date_naissance
    HAVING COUNT(DISTINCT code_commune) > 1
)
SELECT
    LEFT(MD5(COALESCE(d.nom, '') || '|' || d.prenom || '|' || d.date_naissance || '|' || d.sexe), 16) AS id_elu,
    d.nom,
    d.prenom,
    COALESCE(d.code_dep,
             CASE WHEN d.code_commune LIKE '97%' OR d.code_commune LIKE '98%'
                  THEN LEFT(d.code_commune, 3) ELSE LEFT(d.code_commune, 2) END) AS code_dep,
    COALESCE(d.lib_dep, d.lib_csp_part)                                          AS lib_dep,
    d.code_commune,
    d.lib_commune,
    d.sexe,
    CASE WHEN d.date_naissance::date >= DATE '1910-01-01' THEN d.date_naissance::date END AS date_naissance,
    d.code_csp,
    d.lib_csp,
    d.date_debut_mandat::date                                                    AS date_debut_mandat,
    d.lib_fonction,
    d.date_debut_fonction::date                                                  AS date_debut_fonction,
    d.nationalite,
    (d.date_naissance::date < DATE '1910-01-01')                                 AS flag_naissance_aberrante,
    (h.nom IS NOT NULL OR h.prenom IS NOT NULL)                                  AS flag_homonyme
FROM dedoublonne d
LEFT JOIN homonymes h
       ON h.nom IS NOT DISTINCT FROM d.nom
      AND h.prenom = d.prenom
      AND h.date_naissance = d.date_naissance
WHERE d.rang = 1;

-- 3.3 Libellé de département encore manquant
UPDATE silver.conseillers_municipaux c
SET lib_dep = r.lib_dep
FROM (SELECT code_dep, MAX(lib_dep) AS lib_dep
      FROM silver.conseillers_municipaux
      WHERE lib_dep IS NOT NULL GROUP BY code_dep) r
WHERE c.lib_dep IS NULL AND c.code_dep = r.code_dep;

-- 3.4 Suppression de la table intermédiaire
DROP TABLE silver.tmp_conseillers;

