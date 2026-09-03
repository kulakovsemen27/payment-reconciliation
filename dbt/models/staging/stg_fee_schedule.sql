{{ config(materialized='table', schema='staging') }}

select distinct
    psp,
    account,
    cast(valid_from as date) as valid_from,
    cast(percent_fee as decimal(18, 10)) as percent_fee,
    cast(fixed_fee as decimal(20, 8)) as fixed_fee,
    fixed_fee_currency
from {{ ref('fee_schedule') }}
