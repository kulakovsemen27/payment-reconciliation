{{ config(materialized='table', schema='intermediate') }}

select * from {{ ref('int_paypal_us_fees') }}
union all
select * from {{ ref('int_paypal_eu_fees') }}
union all
select * from {{ ref('int_dlocal_fees') }}
union all
select * from {{ ref('int_adyen_fees') }}
union all
select * from {{ ref('int_google_play_fees') }}
