SELECT
    CAST(TO_CHAR(d, 'YYYYMMDD') AS INT) AS date_key,
    CAST(d AS DATE)                     AS date_jour,
    EXTRACT(YEAR FROM d)::INT           AS annee,
    EXTRACT(QUARTER FROM d)::INT        AS trimestre,
    EXTRACT(MONTH FROM d)::INT          AS mois,
    EXTRACT(ISODOW FROM d) IN (6, 7)    AS est_weekend
FROM generate_series(DATE '2026-01-01', DATE '2026-12-31', INTERVAL '1 day') AS d
