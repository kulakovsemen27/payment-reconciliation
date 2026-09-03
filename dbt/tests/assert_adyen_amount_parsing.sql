-- These fields are legitimately nullable; only invalid nonempty text is an error.
select "Psp Reference", "Record Type", source_file
from {{ ref('adyen_payment_accounting') }}
where ("Gross Debit" is not null and try_cast("Gross Debit" as decimal(20, 8)) is null)
    or ("Gross Credit" is not null and try_cast("Gross Credit" as decimal(20, 8)) is null)
    or ("Commission" is not null and try_cast("Commission" as decimal(20, 8)) is null)
    or ("Markup" is not null and try_cast("Markup" as decimal(20, 8)) is null)
    or ("Net Debit" is not null and try_cast("Net Debit" as decimal(20, 8)) is null)
    or ("Net Credit" is not null and try_cast("Net Credit" as decimal(20, 8)) is null)
