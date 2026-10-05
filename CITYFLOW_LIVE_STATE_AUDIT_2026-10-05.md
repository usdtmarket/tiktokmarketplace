# CITYFLOW V1 — Live State Audit

Date: 2026-10-05
Supabase project: `kjtafkgrxdabooewlgyp`

## Verified
- Status: ACTIVE_HEALTHY
- Region: eu-west-3
- PostgreSQL: 17.6
- Public tables: 61
- Public tables with RLS enabled: 61
- Public RLS policies: 117
- Public SQL functions: 12
- Public triggers: 45
- Security Advisor: 0 lints
- Performance Advisor: unused-index notices only; no correctness/security blocker identified
- Core seeded categories: 7
- ARBIPOOL: untouched

## Source-control finding
The live database records 34 migrations. Several live migration records are not represented by exact SQL files in the current repository, and some migration names reuse numeric prefixes (for example 007/008/009/010) across separate migration generations.

Therefore the repository is not yet an exact reproducible source of the current live database state.

## Decision
Do not fabricate missing historical SQL.
Do not merge this branch to main as a production release.
Recover the original migration SQL from an authoritative source, or create and commit a clearly labelled live schema snapshot generated from the database catalog.

## Current production blockers
1. Migration/source parity.
2. CMI production integration and cryptographic verification.
3. Authenticated populated E2E campaign.
4. Staging/release validation.
5. Load/resilience and final observability checks.
