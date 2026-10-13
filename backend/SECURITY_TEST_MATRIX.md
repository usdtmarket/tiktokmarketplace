# CITYFLOW V1 — Security / Integration Test Matrix

These are executable test cases to run once a dedicated CITYFLOW Supabase project exists.

| ID | Test | Expected |
|---|---|---|
| AUTH-01 | anonymous calls `booking-create` | 401 |
| AUTH-02 | invalid bearer token | 401 |
| RLS-01 | customer reads another customer's booking | 0 rows / denied |
| RLS-02 | customer updates protected booking totals | denied / unchanged |
| RLS-03 | customer writes `payments.status` directly | denied |
| BOOK-01 | quote unpublished listing | rejected |
| BOOK-02 | overlapping confirmed booking | rejected |
| BOOK-03 | two concurrent booking creates | max one succeeds for a single-capacity listing |
| BOOK-04 | same idempotency key retried | same booking returned |
| ORDER-01 | client submits fake price | server ignores client price |
| ORDER-02 | insufficient inventory | rejected |
| ORDER-03 | same idempotency key retried | same order returned |
| PAY-01 | payment webhook without signature | 401 |
| PAY-02 | duplicate provider event | idempotent |
| REVIEW-01 | review without completed paid transaction | rejected |
| REVIEW-02 | review after completed transaction | created as pending moderation |
| SECRET-01 | service role key in client bundle | must not exist |

## Production gate
Do not call CITYFLOW production-ready until these tests pass against the dedicated project and payment provider sandbox.
