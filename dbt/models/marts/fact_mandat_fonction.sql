-- 1 ligne = 1 élu × 1 commune × 1 fonction (fonction "Sans fonction" si vide)
-- fait sans mesure : on compte les lignes
select
    {{ dbt_utils.generate_surrogate_key(['nom_elu', 'prenom_elu', 'date_naissance', 'code_sexe']) }} as elu_sk,
    {{ dbt_utils.generate_surrogate_key(['code_commune']) }}                                          as commune_sk,
    {{ dbt_utils.generate_surrogate_key(['code_categorie_socio_pro']) }}                              as cat_socio_prof_sk,

    case
        when libelle_fonction is null then '-1'
        else {{ dbt_utils.generate_surrogate_key(['libelle_fonction']) }}
    end as fonction_sk,

    cast(extract(year from date_debut_mandat) * 10000
       + extract(month from date_debut_mandat) * 100
       + extract(day from date_debut_mandat) as int)  as date_debut_mandat_sk,

    case
        when date_debut_fonction is null then -1
        else cast(extract(year from date_debut_fonction) * 10000
                + extract(month from date_debut_fonction) * 100
                + extract(day from date_debut_fonction) as int)
    end as date_debut_fonction_sk

from {{ ref('int_conseillers_municipaux_territoire') }}
