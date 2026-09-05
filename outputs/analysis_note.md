# Payment Reconciliation — June 2026

## Executive Summary

The payment engine records **$335,668.57**, while provider records total **$134,784.52**. The signed principal difference (`provider - engine`) is **-$200,884.05**; gross absolute differences total **$200,956.79**. Every difference is classified and the unexplained residual is **$0.00**.

The result is dominated by four dLocal FX differences. Three non-USD transactions used an engine rate of `1.0`, overstating their USD value by **$200,679.44**. Excluding all dLocal FX-classified items, the remaining signed difference is **-$205.08**.

| Provider | Engine USD | Provider USD | Signed difference | Absolute difference |
|---|---:|---:|---:|---:|
| Adyen | $32,912.09 | $32,796.14 | -$115.95 | $137.73 |
| dLocal | $215,642.53 | $14,942.35 | -$200,700.18 | $200,701.16 |
| Google Play | $14,744.63 | $14,744.63 | $0.00 | $0.00 |
| PayPal EU | $36,323.01 | $36,230.10 | -$92.91 | $92.91 |
| PayPal US | $36,046.31 | $36,071.30 | $24.99 | $24.99 |
| **Total** | **$335,668.57** | **$134,784.52** | **-$200,884.05** | **$200,956.79** |

## Main Findings

- **dLocal:** three invalid engine FX rates account for **-$200,679.44**. Other findings are one refund amount difference (**-$7.36**), one engine-only sale (**-$7.42**), a settled/disputed status difference (**-$6.45**), one smaller FX difference (**+$0.47**) and two rounding differences (**+$0.02**).
- **Adyen:** a chargeback is missing from the engine (**-$64.79**), two sale amounts differ (**-$40.36**), and one engine-settled payment was declined by Adyen (**-$10.90**). A June/July cutoff difference contributes **-$10.79** and should reverse in the next period. One provider-only sale contributes **+$10.86**; the remaining FX difference is **+$0.03**.
- **PayPal EU:** one refund (**-$26.99**) and one reversal (**-$65.36**) are missing from the engine. One FX difference contributes **-$0.56**.
- **PayPal US:** one payment remains pending in the engine but is settled at PayPal, contributing **+$24.99**.
- **Google Play:** all June principal events match with no USD difference.

## Contracted Fees

Fee schedules are available for Adyen and Google Play only. Reported fees are **$3,078.62**, compared with **$3,067.90** expected under contract, for a potential overcharge of **$10.72**.

| Provider | Reported fees | Expected fees | Potential overcharge |
|---|---:|---:|---:|
| Adyen | $829.42 | $827.70 | $1.72 |
| Google Play | $2,249.20 | $2,240.20 | $9.00 |
| **Total** | **$3,078.62** | **$3,067.90** | **$10.72** |

Adyen has two fee exceptions. Google Play has six charges with a reported fee of `$3.00` each versus `$1.50` expected.

## Recommended Actions

1. Correct the three dLocal transactions with non-USD engine rates of `1.0` and add an upstream validation that rejects this combination.
2. Investigate missing refund, reversal and chargeback events and verify that provider lifecycle updates are processed idempotently by the payment backend.
3. Review the unmatched sales and the three material amount differences against order and settlement records.
4. Raise the **$10.72** fee variance with Adyen and Google Play and verify whether the six Google Play fees came from a duplicated or incorrect fee rule.
5. Confirm that the Adyen cutoff item appears in July before treating it as resolved.

## Assumptions and Data Quality

- June scope is based on UTC financial-event timestamps. Matching uses the full extracts before applying the monthly cutoff.
- Settled sales, refunds, reversals and chargebacks affect principal totals. Pending, declined and disputed events contribute zero until financially settled.
- Provider USD amounts are used where reported; otherwise local amounts use the selected daily USD rate. Calculated USD is rounded to cents at event grain.
- Exact duplicate rows in PayPal US and dLocal were removed in staging and treated as ingestion data-quality findings, not additional financial events.
- PayPal EU dates are interpreted as `DD/MM/YYYY`; three valid but ambiguous date strings remain a source-format risk.
- Google Play has no provider event ID, so events use a descriptive composite identity and are accepted only when the match is one-to-one.
- Fee variances are reported separately and are not netted into the principal reconciliation.
