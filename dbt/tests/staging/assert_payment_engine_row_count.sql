with row_counts as (
    select
        (select count(*) from {{ ref('payment_engine_log') }}) as raw_count,
        (select count(*) from {{ ref('stg_payment_engine') }}) as staging_count
)

select
    raw_count,
    staging_count
from row_counts
where raw_count <> staging_count
