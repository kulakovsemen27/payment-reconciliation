-- Preserve all rows, separately for each report, including any identical values.
with row_counts as (
    select source_file, count(*) as raw_count, 0 as staging_count
    from {{ ref('google_play_earnings') }}
    group by source_file
    union all
    select source_file, 0 as raw_count, count(*) as staging_count
    from {{ ref('stg_google_play') }}
    group by source_file
)

select source_file, sum(raw_count) as raw_count, sum(staging_count) as staging_count
from row_counts
group by source_file
having sum(raw_count) <> sum(staging_count)
