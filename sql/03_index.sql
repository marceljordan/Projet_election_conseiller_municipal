-- =====================================================================
-- 03_index.sql : index testés pour les 3 benchmarks
-- Base : projet_fil_rouge (PostgreSQL 18 local), table de faits ~10 M de lignes
-- Mesure : EXPLAIN (ANALYZE, BUFFERS), 3 passages, médiane (voir docs/rapport_performance.md)
-- Les instructions VACUUM se lancent SEULES, hors transaction (une instruction à la fois).
-- =====================================================================

-- Vue de travail (session) : dernier snapshot
CREATE OR REPLACE TEMP VIEW snap AS
SELECT * FROM gold.fact_mandat_fonction
WHERE sk_date_snapshot = (SELECT MAX(sk_date_snapshot) FROM gold.fact_mandat_fonction);


-- ---------------------------------------------------------------------
-- Benchmark 1 : agrégation avec COUNT(DISTINCT) sur 10 M de lignes
-- Optimisation : réglage de session (ce n'est PAS un index)
-- ---------------------------------------------------------------------
-- Avant : work_mem par défaut (4 Mo)
--   EXPLAIN (ANALYZE, BUFFERS)
--   SELECT c.code_departement, c.libelle_departement, COUNT(DISTINCT s.sk_elu) AS nb_elus
--   FROM snap s JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
--   GROUP BY c.code_departement, c.libelle_departement
--   HAVING COUNT(DISTINCT s.sk_elu) > 150000;
-- Après :
--   SET work_mem = '512MB';   -- à remettre : RESET work_mem;


-- ---------------------------------------------------------------------
-- Benchmark 2 : élus d'un seul département (filtre sélectif)
-- ---------------------------------------------------------------------
--   EXPLAIN (ANALYZE, BUFFERS)
--   SELECT COUNT(DISTINCT s.sk_elu) AS nb_elus, ROUND(AVG(s.age_debut_mandat), 1) AS age_moyen
--   FROM snap s JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
--   WHERE c.code_departement = '93';
CREATE INDEX IF NOT EXISTS idx_fact_sk_commune
    ON gold.fact_mandat_fonction (sk_commune);
ANALYZE gold.fact_mandat_fonction;


-- ---------------------------------------------------------------------
-- Benchmark 3 : parité des maires par département (3 jointures)
-- ---------------------------------------------------------------------
--   EXPLAIN (ANALYZE, BUFFERS)
--   WITH maires AS (
--       SELECT c.code_departement, e.code_sexe
--       FROM snap s
--       JOIN gold.dim_elu e      ON e.sk_elu = s.sk_elu
--       JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
--       JOIN gold.dim_commune c  ON c.sk_commune = s.sk_commune
--       WHERE t.libelle_fonction = 'Maire')
--   SELECT code_departement, COUNT(*) AS nb_maires,
--          ROUND(100.0 * COUNT(*) FILTER (WHERE code_sexe = 'F') / COUNT(*), 1) AS pct_femmes
--   FROM maires GROUP BY code_departement HAVING COUNT(*) >= 20;

-- Index testé SANS effet (le goulot n'est pas le scan de la table de faits) :
--   CREATE INDEX idx_fact_sk_fonction ON gold.fact_mandat_fonction (sk_fonction);
--   -> supprimé : DROP INDEX gold.idx_fact_sk_fonction;

-- Index retenu : index couvrant sur dim_elu (évite 685 701 accès à la table)
CREATE INDEX IF NOT EXISTS idx_elu_couvrant
    ON gold.dim_elu (sk_elu) INCLUDE (code_sexe);
-- À lancer SEUL (VACUUM ne s'exécute pas dans une transaction) :
-- VACUUM ANALYZE gold.dim_elu;

-- Taille des index (pour le rapport)
SELECT indexrelid::regclass AS index, pg_size_pretty(pg_relation_size(indexrelid)) AS taille
FROM pg_index
WHERE indrelid IN ('gold.fact_mandat_fonction'::regclass, 'gold.dim_elu'::regclass);
