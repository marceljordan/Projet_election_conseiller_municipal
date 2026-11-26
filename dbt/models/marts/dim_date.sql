-- 1 ligne = 1 jour, de 2020 à 2032 (couvre le mandat municipal 2026-2032)
with jours as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2033-01-01' as date)"
    ) }}

)

select
    -1                  as date_sk,
    cast(null as date)  as date_jour,
    cast(null as int)   as annee,
    cast(null as int)   as mois,
    cast(null as int)   as jour

union all

select
    cast(extract(year from date_day) * 10000
       + extract(month from date_day) * 100
       + extract(day from date_day) as int)   as date_sk,
    cast(date_day as date)                    as date_jour,
    cast(extract(year from date_day) as int)  as annee,
    cast(extract(month from date_day) as int) as mois,
    cast(extract(day from date_day) as int)   as jour
from jours
