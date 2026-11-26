-- 1 ligne = 1 élu
-- LIMITE DE LA SOURCE : aucun identifiant d'élu fourni.
-- Clé naturelle = nom + prénom + date de naissance + sexe.
-- Deux homonymes parfaits sont donc fusionnés en un seul élu (19 cas dans plusieurs communes).
select distinct
    {{ dbt_utils.generate_surrogate_key(['nom_elu', 'prenom_elu', 'date_naissance', 'code_sexe']) }} as elu_sk,
    nom_elu,
    prenom_elu,
    date_naissance,
    code_sexe,
    code_nationalite
from {{ ref('int_conseillers_municipaux_territoire') }}
