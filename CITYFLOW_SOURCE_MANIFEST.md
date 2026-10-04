# CITYFLOW V1 — Source of Truth

Repository: `usdtmarket/tiktokmarketplace`
Synchronization branch: `cityflow-v1-sync`
Target PR: #1

## Supabase
- Project ref: `kjtafkgrxdabooewlgyp`
- Region: `eu-west-3`
- Status: `ACTIVE_HEALTHY`
- Security Advisor: 0 lints at last audit
- Storage bucket: `cityflow-media` (private)

## Source synchronized
The branch contains the CITYFLOW V1 application source and database baseline, including:
- `backend/001_initial_schema.sql`
- `backend/002_rls_security_hardening.sql`
- transactional migrations `003`–`007`
- media migrations `008`–`010`
- transactional/payment tests
- Edge Functions: feed, search, listing-create, booking, order, payment-intent, payment-webhook boundary, review-create
- live media Edge Functions: media-upload-init, media-upload-confirm, media-moderate, media-public-url
- shared Edge Function HTTP helper
- React/TypeScript/Vite frontend source

## Production gates still open
- CMI merchant affiliation, credentials and official integration kit
- exact CMI cryptographic checkout/webhook implementation
- staging environment
- populated E2E test campaign
- production domain, monitoring and observability validation
- final release/security/load testing

## Security
Never commit Supabase service-role keys, secret keys, provider credentials or real user data.

## Important
This synchronization does not modify the ARBIPOOL Supabase project.
The branch must not be merged to `main` as a production release until the production gates above are closed.
