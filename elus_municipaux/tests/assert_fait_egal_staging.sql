-- Test métier : le fait doit contenir autant de lignes que le staging (pas de perte, pas de doublon).
WITH f AS (SELECT COUNT(*) AS n FROM {{ ref('fct_mandat_fonction') }}),
     s AS (SELECT COUNT(*) AS n FROM {{ ref('stg_silver__conseillers_municipaux') }})
SELECT * FROM f, s WHERE f.n <> s.n
