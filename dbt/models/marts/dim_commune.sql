-- 1 ligne = 1 commune, avec son territoire aplati (pas de dim_departement séparée)
-- group by + max : certaines communes (ex. Martinique) ont le département rempli sur une partie des lignes seulement
select
    {{ dbt_utils.generate_surrogate_key(['code_commune']) }} as commune_sk,
    code_commune,
    max(libelle_commune)         as libelle_commune,
    max(code_departement)        as code_departement,
    max(libelle_departement)     as libelle_departement,
    max(code_collectivite_sp)    as code_collectivite_sp,
    max(libelle_collectivite_sp) as libelle_collectivite_sp,
    max(code_territoire)         as code_territoire,
    max(libelle_territoire)      as libelle_territoire
from {{ ref('int_conseillers_municipaux_territoire') }}
group by code_commune
