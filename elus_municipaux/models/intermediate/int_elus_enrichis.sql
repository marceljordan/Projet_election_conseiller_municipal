-- Intermediate : logique métier réutilisable (âge au début du mandat, indicateur maire).
SELECT
    id_elu,
    nom_elu,
    prenom_elu,
    code_sexe,
    date_naissance,
    code_commune,
    libelle_commune,
    code_departement,
    libelle_departement,
    code_csp,
    libelle_csp,
    libelle_fonction,
    date_debut_mandat,
    date_debut_fonction,
    code_nationalite,
    est_naissance_aberrante,
    est_homonyme,
    CASE
        WHEN est_naissance_aberrante OR date_naissance IS NULL THEN NULL
        ELSE EXTRACT(YEAR FROM AGE(date_debut_mandat, date_naissance))::INT
    END                                         AS age_debut_mandat,
    (libelle_fonction = 'Maire')                AS est_maire
FROM {{ ref('stg_silver__conseillers_municipaux') }}
