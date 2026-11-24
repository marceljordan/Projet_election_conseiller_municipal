--------------Classement (ROW_NUMBER et RANK)
-- dans chaque département, quelles sont les 3 communes
-- dont le conseil municipal est le plus féminisé (conseils de 15 élus ou plus) ?
-- ROW_NUMBER et RANK montre.
WITH conseils AS (
    SELECT c.libelle_departement,
           c.libelle_commune,
           COUNT(*)                                                               AS nb_elus,
           ROUND(100.0 * COUNT(*) FILTER (WHERE e.code_sexe = 'F') / COUNT(*), 1) AS pct_femmes
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_commune c ON c.sk_commune = f.sk_commune
    JOIN gold.dim_elu e     ON e.sk_elu     = f.sk_elu
    GROUP BY c.libelle_departement, c.libelle_commune
    HAVING COUNT(*) >= 15
),
classement AS (
    SELECT conseils.*,
           ROW_NUMBER() OVER (PARTITION BY libelle_departement
                              ORDER BY pct_femmes DESC, nb_elus DESC, libelle_commune) AS position,
           RANK()       OVER (PARTITION BY libelle_departement
                              ORDER BY pct_femmes DESC)                               AS rang_ex_aequo
    FROM conseils
)
SELECT libelle_departement, position, rang_ex_aequo, libelle_commune, nb_elus, pct_femmes
FROM classement
WHERE position <= 3
ORDER BY libelle_departement, position;

------------------Comparaison temporelle (LAG)

-- comment évolue, jour après jour, le nombre de prises de fonction (maires et adjoints) après les élections de mars 2026 ?
WITH installations_jour AS (
    SELECT d.date_complete,
           COUNT(*) AS nb_installations
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_date d ON d.sk_date = f.sk_date_debut_fonction
    WHERE d.date_complete BETWEEN DATE '2026-03-15' AND DATE '2026-04-30'
    GROUP BY d.date_complete
)
SELECT date_complete,
       nb_installations,
       LAG(nb_installations) OVER (ORDER BY date_complete)                    AS nb_jour_precedent,
       nb_installations - LAG(nb_installations) OVER (ORDER BY date_complete) AS variation,
       date_complete - LAG(date_complete) OVER (ORDER BY date_complete)       AS jours_depuis_precedente
FROM installations_jour
ORDER BY date_complete;


-----------------Segmentation (NTILE)

--  la part de femmes maires varie-t-elle selon la taille de la commune ? (communes réparties en 4 quartiles selon la taille du conseil) 
WITH communes AS (
    SELECT f.sk_commune,
           COUNT(*)                                                     AS taille_conseil,
           BOOL_OR(fo.libelle_fonction = 'Maire' AND e.code_sexe = 'F') AS maire_femme,
           BOOL_OR(fo.libelle_fonction = 'Maire')                       AS a_un_maire
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_fonction fo ON fo.sk_fonction = f.sk_fonction
    JOIN gold.dim_elu e       ON e.sk_elu       = f.sk_elu
    GROUP BY f.sk_commune
),
quartiles AS (
    SELECT communes.*,
           NTILE(4) OVER (ORDER BY taille_conseil) AS quartile_taille
    FROM communes
    WHERE a_un_maire
)
SELECT quartile_taille,
       MIN(taille_conseil)                                              AS conseil_min,
       MAX(taille_conseil)                                              AS conseil_max,
       COUNT(*)                                                         AS nb_communes,
       ROUND(100.0 * COUNT(*) FILTER (WHERE maire_femme) / COUNT(*), 1) AS pct_maires_femmes
FROM quartiles
GROUP BY quartile_taille
ORDER BY quartile_taille;



-------- à quel rythme les maires ont-ils été installés ? Cumul des installations et moyenne mobile sur 7 jours (jours du calendrier sont conservés, y compris ceux sans installation).
WITH installations AS (
    SELECT f.sk_date_debut_fonction AS sk_date,
           COUNT(*)                 AS nb
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_fonction fo ON fo.sk_fonction = f.sk_fonction
    WHERE fo.libelle_fonction = 'Maire'
    GROUP BY f.sk_date_debut_fonction
),
maires_jour AS (
    SELECT d.date_complete,
           COALESCE(i.nb, 0) AS nb_maires_installes
    FROM gold.dim_date d
    LEFT JOIN installations i ON i.sk_date = d.sk_date
    WHERE d.date_complete BETWEEN DATE '2026-03-15' AND DATE '2026-06-30'
)
SELECT date_complete,
       nb_maires_installes,
       SUM(nb_maires_installes) OVER (ORDER BY date_complete
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumul_maires,
       ROUND(AVG(nb_maires_installes) OVER (ORDER BY date_complete
                                            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS moyenne_mobile_7
FROM maires_jour
ORDER BY date_complete;

----------------------------Hiérarchie (WITH RECURSIVE)
/* à quel rythme les maires ont-ils été installés ?
   Cumul des installations et moyenne mobile sur 7 jours,
   tous les jours du calendrier sont conservés, y compris ceux sans installation. */
WITH installations AS (
    SELECT f.sk_date_debut_fonction AS sk_date,
           COUNT(*)                 AS nb
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_fonction fo ON fo.sk_fonction = f.sk_fonction
    WHERE fo.libelle_fonction = 'Maire'
    GROUP BY f.sk_date_debut_fonction
),
maires_jour AS (
    SELECT d.date_complete,
           COALESCE(i.nb, 0) AS nb_maires_installes
    FROM gold.dim_date d
    LEFT JOIN installations i ON i.sk_date = d.sk_date
    WHERE d.date_complete BETWEEN DATE '2026-03-15' AND DATE '2026-06-30'
)
SELECT date_complete,
       nb_maires_installes,
       SUM(nb_maires_installes) OVER (ORDER BY date_complete
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumul_maires,
       ROUND(AVG(nb_maires_installes) OVER (ORDER BY date_complete
                                            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS moyenne_mobile_7
FROM maires_jour
ORDER BY date_complete;



-------------with recursive
/*  jusqu'à quel rang descend la chaîne des adjoints au maire
   (1er adjoint -> 2e adjoint -> ...), combien de communes atteignent chaque
   niveau, et quelle est la part de femmes à chaque rang ? */
WITH RECURSIVE fonctions_adjoints AS (
    /* Rang de chaque adjoint : colonne rang_adjoint, ou à défaut le numéro en tête du libellé */
    SELECT fo.sk_fonction,
           fo.libelle_fonction,
           COALESCE(fo.rang_adjoint, SUBSTRING(fo.libelle_fonction FROM '^[0-9]+')::int) AS rang
    FROM gold.dim_fonction fo
    WHERE fo.libelle_fonction ILIKE '%adjoint%'
),
chaine_adjoints AS (
    /* Ancre : le 1er adjoint */
    SELECT fa.sk_fonction, fa.libelle_fonction, fa.rang, 1 AS profondeur
    FROM fonctions_adjoints fa
    WHERE fa.rang = 1
    UNION ALL
    /* Récursion : l'adjoint de rang immédiatement inférieur */
    SELECT fa.sk_fonction, fa.libelle_fonction, fa.rang, ch.profondeur + 1
    FROM fonctions_adjoints fa
    JOIN chaine_adjoints ch ON fa.rang = ch.rang + 1
)
SELECT ch.profondeur,
       ch.libelle_fonction,
       COUNT(DISTINCT f.sk_commune)                                                               AS nb_communes,
       ROUND(100.0 * COUNT(*) FILTER (WHERE UPPER(e.code_sexe) IN ('F', 'FEMME')) / COUNT(*), 1) AS pct_femmes
FROM chaine_adjoints ch
JOIN gold.fact_mandat_fonction f ON f.sk_fonction = ch.sk_fonction
JOIN gold.dim_elu e              ON e.sk_elu      = f.sk_elu
GROUP BY ch.profondeur, ch.libelle_fonction
ORDER BY ch.profondeur;


-------------------------------------------------------Pipeline lisible (CTE enchaînées)
-- quels départements s'écartent le plus de la moyenne
-- nationale de femmes maires ?
-- Étapes : maires -> agrégat par département -> moyenne nationale -> écart -> classement
WITH maires AS (                     
    SELECT f.sk_commune, e.code_sexe
    FROM gold.fact_mandat_fonction f
    JOIN gold.dim_fonction fo ON fo.sk_fonction = f.sk_fonction
    JOIN gold.dim_elu e       ON e.sk_elu       = f.sk_elu
    WHERE fo.libelle_fonction = 'Maire'
),
par_departement AS (              
    SELECT c.libelle_departement,
           COUNT(*)                                  AS nb_maires,
           COUNT(*) FILTER (WHERE m.code_sexe = 'F') AS nb_femmes_maires
    FROM maires m
    JOIN gold.dim_commune c ON c.sk_commune = m.sk_commune
    GROUP BY c.libelle_departement
),
national AS (                      
    SELECT 100.0 * SUM(nb_femmes_maires) / SUM(nb_maires) AS pct_national
    FROM par_departement
),
ecarts AS (                           
    SELECT p.libelle_departement,
           p.nb_maires,
           ROUND(100.0 * p.nb_femmes_maires / p.nb_maires, 1)                  AS pct_femmes_maires,
           ROUND(100.0 * p.nb_femmes_maires / p.nb_maires - n.pct_national, 1) AS ecart_points
    FROM par_departement p
    CROSS JOIN national n
    WHERE p.nb_maires >= 30
)
SELECT ecarts.*,                      
       RANK() OVER (ORDER BY ecart_points DESC) AS rang_feminisation
FROM ecarts
ORDER BY ecart_points DESC;