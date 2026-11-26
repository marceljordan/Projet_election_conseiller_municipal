-- Staging : 1 modèle par table source. Renommage, typage, nettoyage. Aucune jointure.
SELECT
    id_elu,
    UPPER(TRIM(nom))                          AS nom_elu,
    INITCAP(TRIM(prenom))                     AS prenom_elu,
    TRIM(code_dep)                            AS code_departement,
    TRIM(lib_dep)                             AS libelle_departement,
    TRIM(code_commune)                        AS code_commune,
    TRIM(lib_commune)                         AS libelle_commune,
    UPPER(TRIM(sexe))                         AS code_sexe,
    CAST(date_naissance AS DATE)              AS date_naissance,
    COALESCE(NULLIF(TRIM(code_csp), ''), 'NR')            AS code_csp,
    COALESCE(NULLIF(TRIM(lib_csp), ''), 'Non renseignée') AS libelle_csp,
    CAST(date_debut_mandat AS DATE)           AS date_debut_mandat,
        COALESCE(
        NULLIF(
            REGEXP_REPLACE(TRIM(lib_fonction), '^(\d+)[^a-z0-9 ]+me adjoint', E'\\1ème adjoint'),
            ''),
        'Conseiller municipal')                AS libelle_fonction,
    CAST(date_debut_fonction AS DATE)         AS date_debut_fonction,
    UPPER(TRIM(nationalite))                  AS code_nationalite,
    flag_naissance_aberrante                  AS est_naissance_aberrante,
    flag_homonyme                             AS est_homonyme
FROM {{ source('silver', 'conseillers_municipaux') }}
