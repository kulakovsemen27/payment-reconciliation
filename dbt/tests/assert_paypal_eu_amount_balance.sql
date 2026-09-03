-- Fee retains its source sign. Denied attempts have zero Fee/Net.
select
    transaction_id,
    status,
    gross_amount,
    fee_amount,
    net_amount,
    source_file
from {{ ref('stg_paypal_eu') }}
where status in ('Completed', 'Refunded', 'Reversed')
    and (
        gross_amount is null
        or fee_amount is null
        or net_amount is null
        or gross_amount + fee_amount <> net_amount
    )
