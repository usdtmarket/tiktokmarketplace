# CITYFLOW Frontend V1.3

React + TypeScript + Vite frontend for CITYFLOW Martil.

## Connected flows

- Supabase Auth: sign-in / sign-up / session / sign-out.
- Live discovery feed through the `feed` Edge Function.
- Search through the `search` Edge Function.
- Booking quote -> booking create -> payment intent boundary.
- Professional dashboard with real user-owned listings.
- Listing detail surface with approved private-media signed URLs.
- Persistent favorites through the protected `favorites` table.
- Authenticated profile surface with trust score and CityPass balance.
- Authenticated notification center from the protected `notifications` table.
- Professional listing creation through `listing-create` Edge Function.
- Admin surface protected by `user_roles` (`admin` / `super_admin`).
- Demo fallback remains available when Supabase is not configured.

## Environment

```env
VITE_SUPABASE_URL=https://kjtafkgrxdabooewlgyp.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
# Optional. If omitted, the frontend derives /functions/v1 from VITE_SUPABASE_URL.
VITE_CITYFLOW_API_BASE=
```

## Production rules

- Never put a Supabase secret/service-role key in the frontend.
- Payment state and final prices remain server-authoritative.
- CMI checkout remains gated until merchant credentials and the official CMI integration kit are configured.
- New listings are created as `pending_review`; client code never publishes them directly.
- Private media remains served only through short-lived signed URLs from the server function.

## Validation

The source passes a TypeScript transpilation/syntax check. A full `npm run build` still requires dependency installation in an environment with npm registry access.
