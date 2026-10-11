# Admin Center — migration recovery status

Checked against the live Supabase project `kjtafkgrxdabooewlgyp` on 2026-10-11.

## Live database state

- `private.cityflow_admin_action(text, uuid, text, text)` performs admin-only moderation and lifecycle actions and writes before/after data plus reason to `public.audit_logs` in the same transaction.
- `private.cityflow_admin_overview()` returns admin metrics and queues for reviews, listings, businesses, users, media, videos, disputes, fraud cases, audit events, and payments.
- Public SQL wrappers `public.cityflow_admin_action(...)` and `public.cityflow_admin_overview()` delegate to the private functions.
- The action function checks `auth.uid()` and `private.is_admin()`, rejects short reasons for sensitive actions, prevents self-suspension, and restricts action against admin accounts to super-admins.
- Supabase Security Advisor returned zero security lints on this check.

## Reproducibility caveat

The live database contains these functions, but their complete definitions have not yet been committed as a standalone migration in this repository. Do not treat the migration history alone as proof that a clean environment can reproduce the current admin center. Before release, commit the complete function definitions and explicit `REVOKE`/`GRANT EXECUTE` statements, then verify from a clean database and rerun the Security Advisor.

## Validation limitation

The current project has no auth users or transaction records, so end-to-end admin actions and queue workflows cannot yet be exercised with real test entities. Do not create production-like test data without an isolated test plan.
