# CITYFLOW V1 — Source of Truth

Repository: `usdtmarket/tiktokmarketplace`
Synchronization branch: `cityflow-v1-sync`
Target PR: #1

## Supabase
- Project ref: `kjtafkgrxdabooewlgyp`
- Region: `eu-west-3`
- Status: `ACTIVE_HEALTHY`
- PostgreSQL: 17.6
- Public tables: 61
- Public tables with RLS: 61/61
- Public RLS policies: 117+
- Public SQL functions: 12
- Public triggers: 45
- Security Advisor: 0 lints
- Storage bucket: `cityflow-media` (private)

## Live migration history
The live project currently contains 35 migration records. Exact SQL for some historical migrations is not present in this repository.

We must not fabricate historical migration SQL. This source-sync discrepancy is documented and deferred to the final source-of-truth/release phase.

## Current synchronization status
The application source is synchronized with the current CITYFLOW build direction. Live security corrections, including the split anonymous/public discovery policies, are reflected in the active project.

## Deferred final integrations
The following are deliberately not part of the current build gate:
- CMI merchant affiliation and credentials
- Official CMI integration kit
- Exact CMI cryptographic checkout/webhook implementation
- Provider refund/cancellation adapter
- Authenticated populated E2E campaign
- Production domain and final observability rollout
- Final load/resilience and release validation

These are the last integration/release tasks. They do not block continued CITYFLOW V1 construction.

## Security
Never commit Supabase service-role keys, secret keys, provider credentials or real user data.

The payment webhook must remain undeployed until provider-specific cryptographic verification is implemented correctly.
