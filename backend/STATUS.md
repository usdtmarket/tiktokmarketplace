# CITYFLOW V1 Backend Status

## Build status
CITYFLOW V1 continues development without requiring the final production integrations to be present.

## Completed
- Dedicated CITYFLOW Supabase project: ACTIVE_HEALTHY
- Core PostgreSQL marketplace schema and transactional foundation
- RLS and security hardening
- Booking quote/create RPCs
- Commerce order creation with inventory reservation
- Booking/order idempotency
- Payment event idempotency and state machine
- Server-only financial RPCs
- Verified-transaction review flow
- Transactional indexes
- Media upload, confirmation, moderation and signed delivery flow
- Edge Functions: feed, search, listing-create, booking-quote, booking-create, order-create, payment-intent, review-create and media functions
- Core marketplace categories seeded
- Security Advisor: 0 lints

## Deferred — final integration only
These items are intentionally removed from the current build path and will be added as the final project step:
- CMI merchant affiliation and credentials
- Official CMI integration kit/test endpoint
- Exact CMI cryptographic checkout/webhook implementation
- Provider refund/cancellation adapter
- Authenticated live E2E campaign with populated test accounts
- Production domain, monitoring and final release validation
- Final load/resilience campaign

These are deferred integrations, not reasons to stop building CITYFLOW V1.

## Security decision
The payment webhook remains intentionally undeployed until the official provider cryptographic verification is available. No fake signature validation or simulated production payment confirmation will be introduced.

## Current live state
- Supabase project: ACTIVE_HEALTHY
- Region: eu-west-3
- PostgreSQL: 17.6
- Public tables: 61
- RLS: 61/61 application tables
- Public RLS policies: 117+
- Security Advisor: 0 lints
- Auth users: 0
- Published listings: 0
- Approved videos: 0

## V1.5 integration update
- Feed returns category, location and business display context.
- Search returns category, location and business display context.
- Anonymous discovery policies are separated from authenticated/admin policies.
- Media storage remains private with signed URLs.
- Payment remains server-authoritative.

## Release rule
The project can continue to be built and finalized without the deferred integrations above. They are the final integration/release phase, not the current development gate.
