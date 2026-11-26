-- 1 ligne = 1 fonction exécutive, + membre par défaut "Sans fonction"
with fonctions as (

    select distinct libelle_fonction
    from {{ ref('int_conseillers_municipaux_territoire') }}
    where libelle_fonction is not null

)

select
    '-1'            as fonction_sk,
    'Sans fonction' as libelle_fonction

union all

select
    {{ dbt_utils.generate_surrogate_key(['libelle_fonction']) }} as fonction_sk,
    libelle_fonction
from fonctions
