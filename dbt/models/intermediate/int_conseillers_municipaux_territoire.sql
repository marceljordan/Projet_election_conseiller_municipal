{{ config(materialized='table') }}

with stg as (

    select * from {{ ref('stg_conseillers_municipaux') }}

),

departements as (

    select code_departement, max(libelle_departement) as libelle_departement
    from stg
    where code_departement is not null
    group by code_departement

),

corrige as (

    select
        *,
        case
            when code_departement is null
                 and code_collectivite_sp is null
                 and left(code_commune, 2) not in ('97', '98')
                then left(code_commune, 2)
            else code_departement
        end as code_dep,
        (code_departement is null
         and code_collectivite_sp is null
         and left(code_commune, 2) not in ('97', '98')) as est_departement_deduit
    from stg

),

dedoublonne as (

    select
        *,
        row_number() over (
            partition by nom_elu, prenom_elu, date_naissance, code_sexe, code_commune, libelle_fonction
            order by date_debut_mandat desc
        ) as rang
    from corrige

)

select
    c.code_dep                                                  as code_departement,
    d.libelle_departement,
    c.code_collectivite_sp,
    c.libelle_collectivite_sp,
    coalesce(c.code_dep, c.code_collectivite_sp)                as code_territoire,
    coalesce(d.libelle_departement, c.libelle_collectivite_sp)  as libelle_territoire,
    c.code_commune,
    c.libelle_commune,
    c.nom_elu,
    c.prenom_elu,
    c.code_sexe,
    c.date_naissance,
    c.code_nationalite,
    c.code_categorie_socio_pro,
    c.libelle_categorie_socio_pro,
    c.date_debut_mandat,
    c.libelle_fonction,
    c.date_debut_fonction,
    c.est_departement_deduit

from dedoublonne c
left join departements d on c.code_dep = d.code_departement
where c.rang = 1