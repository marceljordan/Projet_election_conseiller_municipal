with source as (

    select * from {{ source('data_gouv', 'conseillers_municipaux') }}

),

renamed as (

    select
        -- territoire
        nullif(trim("Code du département"), '')                               as code_departement,
        nullif(trim("Libellé du département"), '')                            as libelle_departement,
        nullif(trim("Code de la collectivité à statut particulier"), '')      as code_collectivite_sp,
        nullif(trim("Libellé de la collectivité à statut particulier"), '')   as libelle_collectivite_sp,
        trim("Code de la commune")                                            as code_commune,
        trim("Libellé de la commune")                                         as libelle_commune,

        -- élu
        trim("Nom de l'élu")                                                  as nom_elu,
        trim("Prénom de l'élu")                                               as prenom_elu,
        trim("Code sexe")                                                     as code_sexe,
        cast("Date de naissance" as date)                                     as date_naissance,
        trim("Code nationalité")                                              as code_nationalite,

        -- catégorie socio-professionnelle
        trim("Code de la catégorie socio-professionnelle")                    as code_categorie_socio_pro,
        trim("Libellé de la catégorie socio-professionnelle")                 as libelle_categorie_socio_pro,

        -- mandat et fonction
        cast("Date de début du mandat" as date)                               as date_debut_mandat,
        nullif(trim("Libellé de la fonction"), '')                            as libelle_fonction,
        cast(nullif(trim("Date de début de la fonction"), '') as date)        as date_debut_fonction

    from source

)

select * from renamed