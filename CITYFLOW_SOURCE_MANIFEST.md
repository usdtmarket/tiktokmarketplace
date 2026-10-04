# CITYFLOW V1 — Source of Truth

Repository target: `usdtmarket/tiktokmarketplace`

## Supabase
- Project ref: `kjtafkgrxdabooewlgyp`
- Region: `eu-west-3`
- Status: ACTIVE_HEALTHY
- Security Advisor: 0 security lints
- Storage bucket: `cityflow-media` (private)

## Current application artifacts
The authoritative implementation currently exists in the CITYFLOW project workspace and deployed Supabase Edge Functions.

Backend artifact:
- CITYFLOW_V1_backend_v1.5.zip
- Includes transactional core, payment state machine, CMI gate, Edge Functions, tests and migrations 003–007.

Frontend artifact:
- CITYFLOW_frontend_v1.2.zip
- React + TypeScript + Vite frontend.

Additional live Supabase work not present in v1.5 archive:
- media upload init/confirm
- media moderation
- media signed/public URL
- migrations 008–010 for media upload/storage/moderation

## Production gates
- CMI merchant credentials/integration kit: pending
- CMI cryptographic webhook: intentionally not deployed
- E2E test data: pending
- Staging environment: pending
- Production domain/monitoring: pending

## Security rule
Never commit Supabase service-role/secret keys or real credentials.

## Synchronization status
This branch is the controlled synchronization branch. The GitHub connector available to this workspace cannot directly read local filesystem paths, so binary/source archives must be transferred through GitHub's content API rather than fabricated. No credentials or production secrets are being copied.
