-- Count excess exact copies independently of the staging model's DISTINCT.
with duplicate_groups as (
    select
        *,
        count(*) - 1 as excluded_count
    from {{ ref('paypal_eu_activity') }}
    group by all
    having count(*) > 1
),

row_counts as (
    select
        (select count(*) from {{ ref('paypal_eu_activity') }}) as raw_count,
        (select count(*) from {{ ref('stg_paypal_eu') }}) as staging_count,
        (select coalesce(sum(excluded_count), 0) from duplicate_groups) as excluded_copy_count
)

select
    raw_count,
    staging_count,
    excluded_copy_count
from row_counts
where raw_count <> staging_count + excluded_copy_count
