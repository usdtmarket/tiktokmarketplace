# CITYFLOW V1 — Backend Foundation

Production-oriented backend scaffold for CITYFLOW Martil.

## Stack
- Supabase PostgreSQL / PostGIS / pgvector
- Supabase Auth
- Supabase Edge Functions (TypeScript / Deno)
- RLS + server-side transactional RPCs

## Functions
- `feed` — public discovery feed
- `search` — text/category discovery
- `listing-create` — authenticated business/customer listing creation
- `booking-quote` — server-side booking quote
- `booking-create` — transactional booking creation
- `order-create` — transactional commerce order creation
- `payment-intent` — payment provider abstraction boundary
- `payment-webhook` — verified webhook boundary placeholder
- `review-create` — verified transaction review

## Deployment status
NOT DEPLOYED. No CITYFLOW Supabase project is connected yet.
Do not connect this package to ARBIPOOL.

## Required environment variables
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEYS` (injected by Supabase)
- `SUPABASE_SECRET_KEYS` (injected by Supabase; server-side only; never expose to clients)
- payment provider secrets when a provider is selected

## Local verification
Use the current Supabase CLI and Docker, then:

```bash
supabase start
supabase functions serve feed
```

For SQL, apply migrations only after a dedicated CITYFLOW database exists.
