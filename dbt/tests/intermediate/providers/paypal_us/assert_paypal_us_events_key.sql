select psp, provider_event_id
from {{ ref('int_paypal_us_events') }}
group by psp, provider_event_id
having count(*) > 1
