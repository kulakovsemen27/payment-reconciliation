select rate_date, currency, published_at, count(*) as row_count
from {{ ref('stg_fx_rates') }}
group by rate_date, currency, published_at
having count(*) > 1
