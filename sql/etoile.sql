-- DIM_DATE
INSERT INTO gold.dim_date (sk_date, date_complete, annee, trimestre, mois, jour, jour_semaine_iso, est_weekend)
SELECT to_char(d, 'YYYYMMDD')::int, d,
       extract(year FROM d), extract(quarter FROM d), extract(month FROM d), extract(day FROM d),
       extract(isodow FROM d), extract(isodow FROM d) IN (6, 7)
FROM generate_series('2020-01-01'::date, '2035-12-31'::date, interval '1 day') AS d;

-- DIM_COMMUNE (1 ligne par code, département cohérent en priorité)
INSERT INTO gold.dim_commune (sk_commune, code_commune, libelle_commune, code_departement, libelle_departement)
SELECT row_number() OVER (ORDER BY code_commune), code_commune, lib_commune, code_dep, lib_dep
FROM (
         SELECT DISTINCT ON (code_commune) code_commune, lib_commune, code_dep, lib_dep
         FROM silver.conseillers_municipaux
         ORDER BY code_commune, code_dep IS NULL, code_commune NOT LIKE code_dep || '%'
     ) s;

-- DIM_ELU (1 ligne par id_elu)
INSERT INTO gold.dim_elu (sk_elu, cle_naturelle, nom, prenom, nom_complet, code_sexe, date_naissance, annee_naissance, code_nationalite, est_francais)
SELECT row_number() OVER (ORDER BY id_elu), id_elu, nom, prenom, prenom || ' ' || nom,
       sexe, date_naissance, extract(year FROM date_naissance), nationalite, nationalite = 'FR'
FROM (
         SELECT DISTINCT ON (id_elu) id_elu, nom, prenom, sexe, date_naissance, nationalite
         FROM silver.conseillers_municipaux
         ORDER BY id_elu
     ) s;

-- DIM_FONCTION
INSERT INTO gold.dim_fonction (sk_fonction, libelle_fonction)
SELECT row_number() OVER (ORDER BY lib_fonction), lib_fonction
FROM (SELECT DISTINCT coalesce(lib_fonction, 'Conseiller municipal') AS lib_fonction
      FROM silver.conseillers_municipaux) s;

-- DIM_CAT_SOCIO_PROF (1 ligne par code)
INSERT INTO gold.dim_cat_socio_prof (sk_csp, code_csp, libelle_csp, code_groupe)
SELECT row_number() OVER (ORDER BY code_csp), code_csp, lib_csp, left(code_csp, 1)
FROM (
         SELECT DISTINCT ON (code_csp) code_csp, lib_csp
         FROM silver.conseillers_municipaux
         ORDER BY code_csp
     ) s;

-- FACT
INSERT INTO gold.fact_mandat_fonction
(sk_date_snapshot, sk_elu, sk_commune, sk_fonction, sk_csp,
 sk_date_debut_mandat, sk_date_debut_fonction, age_debut_mandat, nb_mandat)
SELECT 20261124,
       e.sk_elu, c.sk_commune, f.sk_fonction, k.sk_csp,
       to_char(s.date_debut_mandat,   'YYYYMMDD')::int,
       to_char(s.date_debut_fonction, 'YYYYMMDD')::int,
       extract(year FROM age(s.date_debut_mandat, s.date_naissance)),
       1
FROM silver.conseillers_municipaux s
         JOIN gold.dim_elu e            ON e.cle_naturelle = s.id_elu
         JOIN gold.dim_commune c        ON c.code_commune = s.code_commune
         JOIN gold.dim_fonction f       ON f.libelle_fonction = coalesce(s.lib_fonction, 'Conseiller municipal')
         JOIN gold.dim_cat_socio_prof k ON k.code_csp = s.code_csp;