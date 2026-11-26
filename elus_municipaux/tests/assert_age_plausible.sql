-- Test métier : un élu a entre 16 et 110 ans au début du mandat (NULL accepté).
SELECT * FROM {{ ref('fct_mandat_fonction') }}
WHERE age_debut_mandat IS NOT NULL AND age_debut_mandat NOT BETWEEN 16 AND 110
