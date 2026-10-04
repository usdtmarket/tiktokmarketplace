# CITYFLOW V1 Backend Status

## Completed
- Dedicated CITYFLOW Supabase project: ACTIVE_HEALTHY
- Migrations 001–006 applied
- Transactional booking quote/create RPCs
- Transactional commerce order creation with inventory reservation
- Booking/order idempotency keys
- Payment event idempotency table
- Payment state machine and atomic booking/order synchronization
- Server-only payment RPCs
- Verified-transaction review RPC
- Transactional foreign-key indexes
- Edge Functions deployed: feed, search, listing-create, booking-quote, booking-create, order-create, payment-intent v2, review-create
- Edge Functions use Supabase publishable/secret key environment variables

## Pending production gates
- CMI merchant affiliation and credentials
- CMI adapter boundary + contract tests (completed; cryptographic provider mapping intentionally gated)
- Official CMI integration kit/test endpoint
- Exact CMI cryptographic request/response signing implementation
- CMI checkout redirect and webhook deployment
- Refund/cancellation provider adapter
- Full live integration test suite with authenticated test accounts (test harness/plan prepared; execution awaits seeded test accounts)
- Production frontend/domain/monitoring rollout

## Security decision
`payment-webhook` is intentionally NOT deployed until provider-specific cryptographic verification exists. A webhook that merely checks for a signature header is not acceptable for production.

## Known Supabase advisor items
- `public.spatial_ref_sys` remains an extension-owned PostGIS table with RLS disabled. Do not alter it blindly.
- PostGIS/vector extension placement and extension-owned SECURITY DEFINER warnings remain for separate hardening review.
- Sensitive server-controlled RLS tables intentionally have no client policies.

## Critical rule
ARBIPOOL is not used by CITYFLOW.

## V1.5 integration update
- Core marketplace categories seeded: Immobilier, Hébergement, Restaurants, Commerces, Services, Mobilité, Loisirs.
- Feed Edge Function v3 now returns category, location and business display context.
- Search Edge Function v3 now returns category, location and business display context and is GET-based for frontend discovery.
- Security advisor currently returns no lints.
- CMI webhook/checkout gate remains unchanged and production-safe.
