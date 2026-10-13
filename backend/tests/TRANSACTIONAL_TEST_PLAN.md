# CITYFLOW V1 — Transactional Test Plan

## Preconditions
- Dedicated CITYFLOW Supabase project only.
- At least one authenticated test user, one business, one bookable listing, availability and pricing.
- No production payment credentials required for DB state-machine tests.

## Required scenarios
1. Booking quote returns server-calculated amount.
2. Booking create succeeds with idempotency key.
3. Repeating booking create with the same idempotency key returns the same booking.
4. Overlapping booking is rejected.
5. Payment record is created exactly once for a pending transaction.
6. Duplicate provider event is idempotent.
7. Capture transitions payment to `captured` and transaction to `confirmed`.
8. Failure transitions payment to `failed` without confirming the transaction.
9. Refund is accepted only from a refundable state.
10. Invalid capture/refund transitions are rejected.
11. Client roles cannot execute server-only payment RPCs.
12. Review creation is accepted only for a verified completed transaction.

## CMI gate
Do not enable production checkout/webhook until the official CMI merchant integration kit defines:
- exact endpoint;
- exact field names and encoding;
- signature/hash algorithm;
- merchant/store identifiers;
- test credentials;
- callback/return semantics.
