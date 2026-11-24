--------------------controle 
-- 4.1 Bilan qualité du silver
SELECT COUNT(*)                                                      AS nb_lignes,
       COUNT(*) FILTER (WHERE code_dep IS NULL)                      AS dep_manquant,
       COUNT(*) FILTER (WHERE lib_dep IS NULL)                       AS lib_dep_manquant,
       COUNT(*) FILTER (WHERE flag_naissance_aberrante)              AS naissance_aberrante,
       COUNT(*) FILTER (WHERE flag_homonyme)                         AS lignes_homonymes,
       COUNT(*) FILTER (WHERE lib_fonction = 'Conseiller municipal') AS sans_fonction,
       COUNT(DISTINCT id_elu)                                        AS nb_elus_distincts
FROM silver.conseillers_municipaux;

-- 4.2 Lignes retirées entre bronze et silver
SELECT (SELECT COUNT(*) FROM bronze.bronze_conseillers_municipal)
     - (SELECT COUNT(*) FROM silver.conseillers_municipaux) AS lignes_retirees;

-- 4.3 Vérification des codes (zéros de tête conservés)
SELECT code_dep, code_commune, lib_commune
FROM silver.conseillers_municipaux
WHERE code_dep IN ('01', '2A', '971')
LIMIT 5;

-- 4.4 Vérification du nom et du prénom
SELECT COUNT(*) FILTER (WHERE nom IS NULL OR nom = '')       AS nom_vide,
       COUNT(*) FILTER (WHERE prenom IS NULL)                AS prenom_vide,
       COUNT(*) FILTER (WHERE nom = 'NA')                    AS nom_na_conserve
FROM silver.conseillers_municipaux;

-- 4.5 Aperçu des données nettoyées
SELECT id_elu, nom, prenom, sexe, date_naissance, lib_commune, lib_fonction
FROM silver.conseillers_municipaux
LIMIT 10;