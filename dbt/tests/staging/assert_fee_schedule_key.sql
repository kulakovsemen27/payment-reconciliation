select psp, account, valid_from
from {{ ref('stg_fee_schedule') }}
group by psp, account, valid_from
having count(*) > 1
    or psp is null
    or account is null
    or valid_from is null
