-- Dimension élu : une ligne par élu.
SELECT
    id_elu                         AS elu_key,
    MAX(nom_elu)                   AS nom_elu,
    MAX(prenom_elu)                AS prenom_elu,
    MAX(code_sexe)                 AS code_sexe,
    MAX(date_naissance)            AS date_naissance,
    MAX(code_nationalite)          AS code_nationalite,
    BOOL_OR(est_homonyme)          AS est_homonyme
FROM {{ ref('int_elus_enrichis') }}
GROUP BY id_elu
