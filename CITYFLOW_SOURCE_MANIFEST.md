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
- Public RLS policies: 117
- Public SQL functions: 12
- Public triggers: 45
- Security Advisor: 0 lints
- Storage bucket: `cityflow-media` (private)

## Live migration history
The live project contains 34 migration records. The history includes migrations that are not currently represented by exact SQL files in this repository:

- 001_initial_schema
- 002_rls_security_hardening
- 003_transactional_core
- 004_backend_function_permissions
- 005_transactional_indexes
- 006_payment_state_machine
- 007_rls_helpers_private_schema
- 008_rls_policy_cleanup_and_initplan
- 009_missing_rls_policies
- 010_foreign_key_indexes
- 011_move_vector_extension
- 012_move_postgis_to_extensions_schema
- 007_core_categories
- 008_media_upload_contract
- 009_media_storage
- 010_media_moderation_publish
- 013_fix_protected_fields_trigger_and_close_insert_holes
- 014_add_media_uploads_listing_id_index
- 015_harden_transactional_and_media
- 016_harden_verified_reviews
- 017_close_direct_review_insert_bypass
- harden_admin_moderation_access
- consolidate_admin_select_policies
- 018_add_user_profile_rls
- 019_remove_redundant_user_profile_rls
- 020_harden_payment_event_amount_currency
- 021_harden_message_identity_fields
- 022_harden_analytics_ingestion
- 023_remove_legacy_analytics_anon_insert
- 024_optimize_analytics_rls_initplan
- 025_add_admin_analytics_read
- 027_consolidate_admin_update_policies
- 028_admin_dispute_fraud_controls
- 029_harden_analytics_event_identity
- 030_moderator_media_access
- 031_consolidate_media_upload_select_policy
- 032_harden_media_upload_metadata
- 033_fix_private_helper_schema_references
- 034_trace_order_payment_runtime_hotfixes

## Synchronization status
This branch contains the application source and the database baseline through the repository's committed migrations. It does **not** yet contain exact SQL for every migration recorded in the live project.

We must not fabricate or reconstruct historical migration SQL and label it as original. The remaining source-of-truth gate is therefore migration-source recovery or a verified schema export/snapshot that can reproduce the current live state.

## Production gates still open
- exact live migration/source synchronization
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
