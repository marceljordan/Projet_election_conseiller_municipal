select
    {{ dbt_utils.generate_surrogate_key(['code_categorie_socio_pro']) }} as cat_socio_prof_sk,
    code_categorie_socio_pro,
    max(libelle_categorie_socio_pro) as libelle_categorie_socio_pro
from {{ ref('int_conseillers_municipaux_territoire') }}
group by code_categorie_socio_pro