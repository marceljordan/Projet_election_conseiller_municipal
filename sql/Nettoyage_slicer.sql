-- traitement et  nettoyage de  la data avant envoie vers  silver 
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'bronze' AND table_name = 'bronze_conseillers_municipal'
ORDER BY ordinal_position;

-- 2.1 Volume
SELECT COUNT(*) AS nb_lignes FROM bronze.bronze_conseillers_municipal;

-- 2.2 Valeurs manquantes
SELECT
  COUNT(*) FILTER (WHERE NULLIF(TRIM("Code du département"), '') IS NULL)          AS dep_vide,
  COUNT(*) FILTER (WHERE NULLIF(TRIM("Libellé du département"), '') IS NULL)       AS lib_dep_vide,
  COUNT(*) FILTER (WHERE NULLIF(TRIM("Nom de l'élu"), '') IS NULL)                 AS nom_vide,
  COUNT(*) FILTER (WHERE NULLIF(TRIM("Libellé de la fonction"), '') IS NULL)       AS fonction_vide,
  COUNT(*) FILTER (WHERE NULLIF(TRIM("Date de début de la fonction"), '') IS NULL) AS date_fonction_vide
FROM bronze.bronze_conseillers_municipal;

-- 2.3 Dates de naissance aberrantes
SELECT "Date de naissance", "Libellé de la commune"
FROM bronze.bronze_conseillers_municipal
WHERE "Date de naissance"::date < DATE '1910-01-01';

-- 2.4 Lignes sans département
SELECT "Libellé de la collectivité à statut particulier", COUNT(*)
FROM bronze.bronze_conseillers_municipal
WHERE NULLIF(TRIM("Code du département"), '') IS NULL
GROUP BY 1;

-- 2.5 Doublons potentiels
SELECT COUNT(*) - COUNT(DISTINCT ("Nom de l'élu", "Prénom de l'élu", "Date de naissance")) AS doublons
FROM bronze.bronze_conseillers_municipal;


