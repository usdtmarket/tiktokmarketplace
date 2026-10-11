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


## Release gate — 2026-10-11

Before promoting this branch:

1. Recover the exact live SQL definitions for admin overview/action and commit them as a reproducible migration with explicit function privileges.
2. Compare all live schema objects against the versioned migrations; do not infer that the source tree reproduces the live database.
3. Create isolated test identities and fixtures only after defining cleanup and data-isolation rules. Exercise customer, business member, moderator, admin, and super-admin permission boundaries.
4. Run frontend typecheck/build and the security test matrix; record actual command output and commit SHA with the release evidence.
5. Keep CMI checkout/webhook disabled until the official merchant kit and provider credentials are available and signature verification can be tested against the provider sandbox.

Current known constraints: the production project has no auth users or booking/order rows, so transaction and admin end-to-end tests cannot yet be considered passed. Security Advisor reported zero lints in the last check, which is not a substitute for functional tests.
