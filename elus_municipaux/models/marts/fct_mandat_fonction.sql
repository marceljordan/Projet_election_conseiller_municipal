-- GRAIN : une ligne = un élu, dans une commune, pour une fonction.
-- Pas de SELECT * : on liste les colonnes.
SELECT
    MD5(CONCAT_WS('|', id_elu, code_commune, libelle_fonction,
                  COALESCE(CAST(date_debut_fonction AS TEXT), ''))) AS mandat_key,
    id_elu                                                          AS elu_key,
    code_commune                                                    AS commune_key,
    MD5(libelle_fonction)                                           AS fonction_key,
    code_csp                                                        AS csp_key,
    CAST(TO_CHAR(date_debut_mandat, 'YYYYMMDD') AS INT)             AS date_debut_mandat_key,
    CAST(TO_CHAR(date_debut_fonction, 'YYYYMMDD') AS INT)           AS date_debut_fonction_key,
    age_debut_mandat
FROM {{ ref('int_elus_enrichis') }}
