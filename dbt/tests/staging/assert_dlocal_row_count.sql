with duplicate_groups as (
    select *, count(*) - 1 as excluded_count
    from {{ ref('dlocal_transactions') }}
    group by all
    having count(*) > 1
),

row_counts as (
    select
        (select count(*) from {{ ref('dlocal_transactions') }}) as raw_count,
        (select count(*) from {{ ref('stg_dlocal') }}) as staging_count,
        (select coalesce(sum(excluded_count), 0) from duplicate_groups) as excluded_copy_count
)

select *
from row_counts
where raw_count <> staging_count + excluded_copy_count
