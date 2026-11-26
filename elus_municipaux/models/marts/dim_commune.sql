-- Dimension commune : une ligne par commune (hiérarchie département aplatie).
SELECT
    code_commune                   AS commune_key,
    MAX(libelle_commune)           AS libelle_commune,
    MAX(code_departement)          AS code_departement,
    MAX(libelle_departement)       AS libelle_departement
FROM {{ ref('int_elus_enrichis') }}
GROUP BY code_commune
