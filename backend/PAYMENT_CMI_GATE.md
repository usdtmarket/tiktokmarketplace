# CITYFLOW — CMI Payment Gate

CMI is the planned Moroccan payment provider for V1.

## Current state
- Payment record creation: deployed.
- Payment state machine: deployed.
- Duplicate provider event protection: deployed.
- Booking/order state synchronization: deployed.
- Real CMI checkout redirect: **not enabled**.
- CMI webhook: **not enabled**.

## Production gate
Do not activate the CMI webhook or checkout until CITYFLOW has the official merchant integration kit/credentials from CMI or its acquiring partner. CMI states that affiliated merchants receive an integration kit with test-environment documentation/scripts; the integration flow uses signed exchanges and supports operations including authorization, refund and cancellation.

The exact CMI signing/canonicalization rules must be implemented from that provider kit. No guessed signature algorithm is accepted for production.

## Expected flow
1. CITYFLOW creates a pending payment record server-side.
2. Server generates the CMI checkout request using the official merchant parameters and signature rules.
3. Customer is redirected to the CMI-hosted secure payment page.
4. CMI returns the provider result.
5. CITYFLOW verifies the provider response cryptographically.
6. CITYFLOW inserts an idempotent `payment_events` record.
7. `cityflow_apply_payment_event` updates the payment atomically.
8. Booking/order moves to `confirmed` only after a verified captured payment.
9. Refunds/cancellations follow the same provider-verified state machine.

Reference: https://www.cmi.co.ma/fr/solutions-paiement-ecommerce
