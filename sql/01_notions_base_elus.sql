-- =====================================================================
-- Notions de base (slides Fondation SQL) adaptées au projet "élus municipaux"
-- Base : projet_fil_rouge (PostgreSQL local) · schéma gold
-- À lancer dans pgAdmin (Query Tool) : sélectionner UN bloc, puis ▶ (F5).
-- Hypothèses à vérifier : libelle_fonction = 'Maire', code_sexe = 'F' / 'M'.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. PRÉPARATION : vue temporaire sur le dernier snapshot
-- (existe seulement pendant votre session pgAdmin, ne modifie rien de durable)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TEMP VIEW snap AS
SELECT *
FROM gold.fact_mandat_fonction
WHERE sk_date_snapshot = (SELECT MAX(sk_date_snapshot) FROM gold.fact_mandat_fonction);


-- =====================================================================
-- A. CONTRAINTES D'INTÉGRITÉ (slide 10) + CARDINALITÉS (slide 11)
-- =====================================================================

-- Cardinalités de votre étoile :
--   dim_elu 1 --- N fact_mandat_fonction   (un élu a une ou plusieurs lignes de fait)
--   dim_commune 1 --- N fact_mandat_fonction
--   dim_fonction 1 --- N fact_mandat_fonction
--   dim_cat_socio_prof 1 --- N fact_mandat_fonction
--   élu N --- N commune/fonction : résolu par la table de faits (table d'association)
--   PK composite de la table de faits : (sk_date_snapshot, sk_elu, sk_commune, sk_fonction)

-- Voir les contraintes réelles de vos tables gold
SELECT conrelid::regclass AS table_cible, conname AS contrainte,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'u' THEN 'UNIQUE' WHEN 'c' THEN 'CHECK' END AS type
FROM pg_constraint
WHERE connamespace = 'gold'::regnamespace
ORDER BY 1, 3;

-- Exemple CREATE TABLE avec toutes les contraintes du slide (table de hiérarchie)
CREATE TABLE IF NOT EXISTS gold.dim_territoire (
    id         TEXT PRIMARY KEY,                                   -- unique + non nul
    nom        TEXT NOT NULL,                                      -- valeur obligatoire
    niveau     TEXT NOT NULL CHECK (niveau IN ('region','departement')),  -- règle métier
    parent_id  TEXT REFERENCES gold.dim_territoire(id) ON DELETE RESTRICT, -- intégrité référentielle
    actif      BOOLEAN DEFAULT TRUE,                               -- valeur par défaut
    UNIQUE (nom, niveau)                                           -- pas de doublon
);

-- Données d'exemple : la région Île-de-France et ses 8 départements
INSERT INTO gold.dim_territoire (id, nom, niveau, parent_id) VALUES
    ('IDF', 'Île-de-France', 'region', NULL),
    ('75', 'Paris',              'departement', 'IDF'),
    ('77', 'Seine-et-Marne',     'departement', 'IDF'),
    ('78', 'Yvelines',           'departement', 'IDF'),
    ('91', 'Essonne',            'departement', 'IDF'),
    ('92', 'Hauts-de-Seine',     'departement', 'IDF'),
    ('93', 'Seine-Saint-Denis',  'departement', 'IDF'),
    ('94', 'Val-de-Marne',       'departement', 'IDF'),
    ('95', 'Val-d''Oise',        'departement', 'IDF')
ON CONFLICT (id) DO NOTHING;


-- =====================================================================
-- B. ORDRE D'ÉCRITURE ≠ ORDRE D'EXÉCUTION (slide 14)
-- FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
-- =====================================================================

-- ERREUR volontaire (alias nb inconnu dans WHERE, car SELECT s'exécute après) :
-- SELECT code_departement, COUNT(*) AS nb FROM gold.dim_commune WHERE nb > 100 GROUP BY 1;

-- Question : quels sont les 5 départements qui ont le plus de communes (plus de 100) ?
SELECT code_departement, COUNT(*) AS nb_communes
FROM gold.dim_commune
GROUP BY code_departement
HAVING COUNT(*) > 100            -- filtre de groupes (HAVING voit les agrégats)
ORDER BY nb_communes DESC        -- ORDER BY peut utiliser l'alias
LIMIT 5;


-- =====================================================================
-- C. WHERE : filtrer les lignes
-- =====================================================================

-- Question : quelles sont les communes de Seine-Saint-Denis ?
SELECT code_commune, libelle_commune
FROM gold.dim_commune
WHERE code_departement = '93'
ORDER BY libelle_commune;

-- Question : combien de communes dans Paris et la petite couronne ? (IN)
SELECT code_departement, libelle_departement, COUNT(*) AS nb_communes
FROM gold.dim_commune
WHERE code_departement IN ('75','92','93','94')
GROUP BY code_departement, libelle_departement;

-- Question : combien de communes commencent par « Saint- » ? (LIKE)
SELECT COUNT(*) AS nb_communes_saint
FROM gold.dim_commune
WHERE libelle_commune LIKE 'Saint-%';

-- Question : combien d'élus avaient entre 18 et 25 ans au début du mandat ? (BETWEEN)
SELECT COUNT(*) AS nb_jeunes_elus
FROM snap
WHERE age_debut_mandat BETWEEN 18 AND 25;


-- =====================================================================
-- D. GROUP BY : de N lignes à un résultat par groupe (slide 20)
-- Règle d'or : chaque colonne du SELECT est dans le GROUP BY ou dans une agrégation.
-- =====================================================================

-- Question : combien d'élus par sexe ?
SELECT code_sexe, COUNT(*) AS nb_elus
FROM gold.dim_elu
GROUP BY code_sexe;

-- Question : combien d'élus et quel âge moyen par fonction ?
SELECT t.libelle_fonction,
       COUNT(*)                          AS nb_lignes,
       ROUND(AVG(s.age_debut_mandat), 1) AS age_moyen
FROM snap s
JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
GROUP BY t.libelle_fonction
ORDER BY nb_lignes DESC;

-- Question : part de femmes par fonction (parité, au cœur de votre sujet)
SELECT t.libelle_fonction,
       COUNT(*) AS nb,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.code_sexe = 'F') / COUNT(*), 1) AS pct_femmes
FROM snap s
JOIN gold.dim_elu e      ON e.sk_elu = s.sk_elu
JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
GROUP BY t.libelle_fonction
ORDER BY pct_femmes;


-- =====================================================================
-- E. WHERE filtre les lignes, HAVING filtre les groupes (slide 21)
-- =====================================================================

-- Question : parmi les élus de 60 ans et plus, quels départements en comptent plus de 20 000 ?
-- (adaptez le seuil à vos volumes)
SELECT c.code_departement, c.libelle_departement,
       COUNT(*) AS nb_elus_60_plus
FROM snap s
JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
WHERE s.age_debut_mandat >= 60                 -- filtre de lignes (avant GROUP BY)
GROUP BY c.code_departement, c.libelle_departement
HAVING COUNT(*) > 20000                        -- filtre de groupes (après GROUP BY)
ORDER BY nb_elus_60_plus DESC;


-- =====================================================================
-- F. JOINTURES (slides 16 à 18)
-- =====================================================================

-- INNER JOIN · Question : combien d'élus par fonction (fonctions ayant des élus) ?
SELECT t.libelle_fonction, COUNT(*) AS nb_elus
FROM snap s
JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
GROUP BY t.libelle_fonction
ORDER BY nb_elus DESC;

-- LEFT JOIN · Question : toutes les fonctions, même celles sans aucun élu
-- COUNT(s.sk_elu) et non COUNT(*) : sinon une fonction sans élu compterait 1.
SELECT t.libelle_fonction, COUNT(s.sk_elu) AS nb_elus
FROM gold.dim_fonction t
LEFT JOIN snap s ON s.sk_fonction = t.sk_fonction
GROUP BY t.libelle_fonction
ORDER BY nb_elus DESC;

-- ANTI-JOINTURE (LEFT JOIN + IS NULL) · Question : quelles fonctions n'ont aucun élu ?
SELECT t.libelle_fonction
FROM gold.dim_fonction t
LEFT JOIN snap s ON s.sk_fonction = t.sk_fonction
WHERE s.sk_fonction IS NULL;


-- =====================================================================
-- G. CROSS JOIN et AUTO-JOINTURE (slide 19)
-- =====================================================================

-- CROSS JOIN · grille complète département × fonction (pour voir les zéros)
WITH deps AS (
    SELECT DISTINCT code_departement
    FROM gold.dim_commune
    WHERE code_departement IN ('75','92','93','94')
),
comptage AS (
    SELECT c.code_departement, s.sk_fonction, COUNT(*) AS nb
    FROM snap s
    JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
    WHERE c.code_departement IN ('75','92','93','94')
    GROUP BY c.code_departement, s.sk_fonction
)
SELECT d.code_departement, f.libelle_fonction, COALESCE(k.nb, 0) AS nb_elus
FROM deps d
CROSS JOIN gold.dim_fonction f
LEFT JOIN comptage k ON k.code_departement = d.code_departement
                    AND k.sk_fonction = f.sk_fonction
ORDER BY d.code_departement, f.libelle_fonction;

-- AUTO-JOINTURE · Question : quels sont les départements directs de l'Île-de-France ?
SELECT enfant.nom AS departement, parent.nom AS region
FROM gold.dim_territoire enfant
LEFT JOIN gold.dim_territoire parent ON parent.id = enfant.parent_id
WHERE parent.nom = 'Île-de-France'
ORDER BY enfant.id;
-- Limite : l'auto-jointure ne remonte qu'un niveau. Pour une profondeur
-- inconnue, utiliser une CTE récursive.


-- =====================================================================
-- H. DEUX PIÈGES DES JOINTURES (slide 20)
-- =====================================================================

-- 1) FAN-OUT : une jointure peut dupliquer les lignes (le COUNT(*) gonfle).
-- Question : combien de lignes pour une commune, avant et après auto-jointure sur la commune ?
-- (peut prendre quelques secondes sur 10 M de lignes)
WITH une_commune AS (
    SELECT sk_commune FROM gold.dim_commune
    WHERE code_departement = '93' ORDER BY code_commune LIMIT 1
)
SELECT
  (SELECT COUNT(*) FROM snap WHERE sk_commune = (SELECT sk_commune FROM une_commune)) AS lignes_avant,
  (SELECT COUNT(*) FROM snap a JOIN snap b ON b.sk_commune = a.sk_commune
    WHERE a.sk_commune = (SELECT sk_commune FROM une_commune))                        AS lignes_apres_jointure;
-- Règle : agréger au bon grain AVANT de joindre, et contrôler COUNT(*) après chaque jointure.
-- Pour compter des élus, utiliser COUNT(DISTINCT sk_elu) : un élu peut cumuler plusieurs fonctions.

-- 2) NULL : le NULL n'est égal à rien (votre colonne libelle_sexe est vide partout)
SELECT COUNT(*)           AS toutes_les_lignes,
       COUNT(libelle_sexe) AS libelle_renseigne,        -- COUNT(colonne) ignore les NULL
       COUNT(*) FILTER (WHERE libelle_sexe IS NULL) AS libelle_null
FROM gold.dim_elu;

SELECT COUNT(*) AS avec_egal_null  FROM gold.dim_elu WHERE libelle_sexe = NULL;   -- 0 ligne !
SELECT COUNT(*) AS avec_is_null    FROM gold.dim_elu WHERE libelle_sexe IS NULL;  -- correct

SELECT code_sexe, COALESCE(libelle_sexe, 'Inconnu') AS libelle, COUNT(*) AS nb
FROM gold.dim_elu
GROUP BY code_sexe, libelle_sexe;


-- =====================================================================
-- I. SOUS-REQUÊTES : quatre usages (slide 21)
-- =====================================================================

-- Scalaire · Question : combien d'élus avaient un âge supérieur à la moyenne au début du mandat ?
SELECT COUNT(*) AS nb_elus_plus_ages
FROM snap
WHERE age_debut_mandat > (SELECT AVG(age_debut_mandat) FROM snap);

-- IN / EXISTS · Question : quelles communes du 93 ont au moins un élu de moins de 25 ans ?
SELECT c.libelle_commune
FROM gold.dim_commune c
WHERE c.code_departement = '93'
  AND EXISTS (
      SELECT 1 FROM snap s
      WHERE s.sk_commune = c.sk_commune
        AND s.age_debut_mandat < 25
  )
ORDER BY c.libelle_commune;

-- Table dérivée (dans le FROM) · Question : combien d'élus par commune en moyenne ?
SELECT ROUND(AVG(nb), 1) AS nb_moyen_elus_par_commune
FROM (
    SELECT sk_commune, COUNT(*) AS nb
    FROM snap
    GROUP BY sk_commune
) t;

-- Corrélée (réévaluée pour chaque ligne) · Question : quelles communes ont plus d'élus
-- que la moyenne des communes de leur propre département ?
WITH elus_par_commune AS (
    SELECT sk_commune, COUNT(*) AS nb
    FROM snap
    GROUP BY sk_commune
)
SELECT c.libelle_commune, c.code_departement, e.nb
FROM elus_par_commune e
JOIN gold.dim_commune c ON c.sk_commune = e.sk_commune
WHERE e.nb > (
    SELECT AVG(e2.nb)
    FROM elus_par_commune e2
    JOIN gold.dim_commune c2 ON c2.sk_commune = e2.sk_commune
    WHERE c2.code_departement = c.code_departement
)
ORDER BY e.nb DESC
LIMIT 50;


-- =====================================================================
-- J. EXERCICES FLASH (slide 22), adaptés au sujet
-- =====================================================================

-- Exercice 1 · JOIN, GROUP BY, HAVING
-- Question : quels départements comptent plus de 5 000 élus, et quel est leur âge moyen au début du mandat ?
SELECT c.code_departement, c.libelle_departement,
       COUNT(DISTINCT s.sk_elu)          AS nb_elus,
       ROUND(AVG(s.age_debut_mandat), 1) AS age_moyen
FROM snap s
JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
GROUP BY c.code_departement, c.libelle_departement
HAVING COUNT(DISTINCT s.sk_elu) > 5000
ORDER BY nb_elus DESC;

-- Exercice 2 · LEFT JOIN et NOT EXISTS
-- Question : quelles communes n'ont aucune femme maire ?
-- Façon 1 : LEFT JOIN + IS NULL
SELECT c.code_commune, c.libelle_commune
FROM gold.dim_commune c
LEFT JOIN (
    SELECT DISTINCT s.sk_commune
    FROM snap s
    JOIN gold.dim_elu e      ON e.sk_elu = s.sk_elu
    JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
    WHERE t.libelle_fonction = 'Maire' AND e.code_sexe = 'F'
) m ON m.sk_commune = c.sk_commune
WHERE m.sk_commune IS NULL;

-- Façon 2 : NOT EXISTS (doit renvoyer le même nombre de lignes)
SELECT c.code_commune, c.libelle_commune
FROM gold.dim_commune c
WHERE NOT EXISTS (
    SELECT 1
    FROM snap s
    JOIN gold.dim_elu e      ON e.sk_elu = s.sk_elu
    JOIN gold.dim_fonction t ON t.sk_fonction = s.sk_fonction
    WHERE s.sk_commune = c.sk_commune
      AND t.libelle_fonction = 'Maire' AND e.code_sexe = 'F'
);

-- Exercice 3 · Sous-requête scalaire
-- Question : quelles communes ont plus d'élus que la moyenne des communes ?
SELECT c.libelle_commune, c.code_departement, COUNT(DISTINCT s.sk_elu) AS nb_elus
FROM snap s
JOIN gold.dim_commune c ON c.sk_commune = s.sk_commune
GROUP BY c.sk_commune, c.libelle_commune, c.code_departement
HAVING COUNT(DISTINCT s.sk_elu) > (
    SELECT AVG(nb) FROM (SELECT COUNT(DISTINCT sk_elu) AS nb FROM snap GROUP BY sk_commune) t
)
ORDER BY nb_elus DESC
LIMIT 50;

-- Exercice 4 · Auto-jointure
-- Question : quels sont les départements directs de la région Île-de-France ?
SELECT enfant.nom AS departement, parent.nom AS region
FROM gold.dim_territoire enfant
JOIN gold.dim_territoire parent ON parent.id = enfant.parent_id
WHERE parent.nom = 'Île-de-France';
