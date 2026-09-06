-- Fee keeps the source sign: a charged fee is negative.
-- Denied attempts have attempted Gross but zero Fee/Net, so are out of scope.
select
    transaction_id,
    status,
    gross_amount,
    fee_amount,
    net_amount,
    source_file
from {{ ref('stg_paypal_us') }}
where status in ('Completed', 'Refunded')
    and (
        gross_amount is null
        or fee_amount is null
        or net_amount is null
        or gross_amount + fee_amount <> net_amount
    )
