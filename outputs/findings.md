# June 2026 — reconciliation findings

**June is fully reconciled.**

| Result | Events | Amount, USD |
|---|---:|---:|
| Matched | 7,697 | $134,623.81 matched on each side |
| Explained differences | 20 | −$200,884.05 net impact |
| **Unexplained differences** | **0** | **$0.00** |

The explained differences have a gross absolute impact of $200,956.79 before positive and negative exceptions offset each other.

## Reconciliation by providers

| Provider | Engine USD | Provider USD | Difference (provider − engine)  |
|---|---:|---:|---:|
| Adyen | $32,912.09 | $32,796.14 | −$115.95 |
| dLocal | $215,642.53 | $14,942.35 | −$200,700.18 |
| Google Play | $14,744.63 | $14,744.63 | $0.00 |
| PayPal EU | $36,323.01 | $36,230.10 | −$92.91 |
| PayPal US | $36,046.31 | $36,071.30 | +$24.99 |
| **Total** | **$335,668.57** | **$134,784.52** | **−$200,884.05** |

## Findings and actions

| Finding | USD impact | Action |
|---|---:|---|
| dLocal: three non-USD engine rates of `1.0` | −$200,679.44 | Correct valuations; validate upstream rates against the FX feed. |
| Missing engine events: Adyen chargeback; PayPal EU refund and reversal | −$157.14 | Investigate lifecycle delivery and replay confirmed missing events. |
| Amount differences: two Adyen sales and one dLocal refund | −$47.72 | Verify order and settlement amounts. |
| Status differences: PayPal US pending/settled, Adyen settled/declined, dLocal settled/disputed | +$7.64 | Verify backend status updates. |
| Unmatched sales: Adyen provider-only and dLocal engine-only | +$3.44 | Trace order and PSP references. |
| Adyen: June engine event settled July 2 | −$10.79 | Follow $10.88 into July; investigate the $0.09 valuation difference. |
| Other FX dates/revisions and cent rounding | −$0.04 | Check FX timing and rounding conventions. |

More details: [Provider × cause counts and impacts](reconciliation_summary.csv) · [20 discrepancy records](reconciliation_details.csv). 

## Contracted fees

| Provider | Reported | Expected | Variance | Exceptions |
|---|---:|---:|---:|---:|
| Adyen | $829.42 | $827.70 | +$1.72 | 2 |
| Google Play | $2,249.20 | $2,240.20 | +$9.00 | 6 |
| **Total** | **$3,078.62** | **$3,067.90** | **+$10.72** | **8** |

Only these providers have supplied contracts. Request clarification of the overcharges: six Google Play charges carry $3.00 fees versus $1.50 expected. 
More details: [Fee summary](fee_reconciliation_summary.csv) · [Evidence and tariffs](fee_reconciliation_details.csv).

---

## Assumptions and data quality

| Area | Treatment |
|---|---|
| Period and status | Match full extracts, then recognize each side in its UTC month. Pending, declined and disputed events contribute zero. |
| FX and rounding | Use reported provider USD, otherwise the latest revision of the latest rate dated on/before the event. Round calculated USD per event. Equal local amounts/rates with a one-cent difference use a provisional rounding tolerance. |
| Duplicates | Exact PayPal US and dLocal copies are removed in staging without financial impact. Google Play descriptive equality does not establish duplication. |
| PayPal EU dates | Prefer DD/MM/YYYY within the filename's export interval; three outliers require MM/DD/YYYY to fall within it. |
| Google Play identity | No source event ID; use descriptive attributes and require one-to-one matches. |
