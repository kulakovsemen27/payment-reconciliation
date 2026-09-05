{{ config(materialized='view', schema='intermediate') }}

select * from {{ ref('int_paypal_us_matches') }}
union all
select * from {{ ref('int_paypal_eu_matches') }}
union all
select * from {{ ref('int_dlocal_matches') }}
union all
select * from {{ ref('int_adyen_matches') }}
union all
select * from {{ ref('int_google_play_matches') }}
