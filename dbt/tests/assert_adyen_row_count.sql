with duplicate_groups as (
    select *, count(*) - 1 as excluded_count
    from {{ ref('adyen_payment_accounting') }}
    group by all
    having count(*) > 1
),

row_counts as (
    select
        (select count(*) from {{ ref('adyen_payment_accounting') }}) as raw_count,
        (select count(*) from {{ ref('stg_adyen') }}) as staging_count,
        (select coalesce(sum(excluded_count), 0) from duplicate_groups) as excluded_copy_count
)

select *
from row_counts
where raw_count <> staging_count + excluded_copy_count
