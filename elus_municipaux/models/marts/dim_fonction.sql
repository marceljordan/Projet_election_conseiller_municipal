SELECT DISTINCT
    MD5(libelle_fonction)          AS fonction_key,
    libelle_fonction,
    (libelle_fonction = 'Maire')   AS est_maire
FROM {{ ref('int_elus_enrichis') }}
