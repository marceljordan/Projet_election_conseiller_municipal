SELECT
    code_csp                       AS csp_key,
    MAX(libelle_csp)               AS libelle_csp
FROM {{ ref('int_elus_enrichis') }}
GROUP BY code_csp
