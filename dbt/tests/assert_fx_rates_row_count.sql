with duplicate_groups as (
    select
        cast(rate_date as date) as rate_date,
        currency,
        cast(usd_rate as decimal(18, 10)) as usd_rate,
        cast(published_at as timestamptz) as published_at,
        count(*) - 1 as excluded_count
    from {{ ref('fx_rates') }}
    group by all
    having count(*) > 1
),

row_counts as (
    select
        (select count(*) from {{ ref('fx_rates') }}) as raw_count,
        (select count(*) from {{ ref('stg_fx_rates') }}) as staging_count,
        (select coalesce(sum(excluded_count), 0) from duplicate_groups) as excluded_copy_count
)

select *
from row_counts
where raw_count <> staging_count + excluded_copy_count
