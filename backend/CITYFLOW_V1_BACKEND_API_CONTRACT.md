# CITYFLOW V1 — Backend / API Contract

## Architecture
- Web / iOS / Android clients
- Supabase Auth for identity and sessions
- PostgreSQL + PostGIS + pgvector
- Supabase Storage for media
- Supabase Realtime for chat, notifications and live status
- Edge Functions / trusted server for privileged business logic
- External providers: payment, maps/geocoding, email/SMS/push, AI models

## Security boundary
### Public
Read-only discovery: active cities/categories, published listings, approved videos/reviews, public business data, public availability/pricing, public trust score.

### Authenticated customer
Own profile, favorites, interactions, booking/order creation, own bookings/orders, chat, reviews, CityPass.

### Business
Own business and authorized members, listings/content, availability/pricing/promotions, booking/order operations.

### Server-only
Payment state mutations, provider webhooks, refunds, commissions, fraud cases, trust calculations, AI execution, audit writes, system settings.

## API domains
### Discovery
`GET /api/v1/feed`
`GET /api/v1/listings`
`GET /api/v1/listings/:id`
`GET /api/v1/categories`
`GET /api/v1/map`
`POST /api/v1/search`

### Business
`POST /api/v1/businesses`
`GET /api/v1/businesses/:id`
`PATCH /api/v1/businesses/:id`
`POST /api/v1/businesses/:id/members`

### Listings
`POST /api/v1/listings`
`GET /api/v1/listings/:id`
`PATCH /api/v1/listings/:id`
`POST /api/v1/listings/:id/media`
`POST /api/v1/listings/:id/availability`
`POST /api/v1/listings/:id/publish`

### Booking
`POST /api/v1/bookings/quote`
`POST /api/v1/bookings`
`GET /api/v1/bookings/:id`
`POST /api/v1/bookings/:id/cancel`
`POST /api/v1/bookings/:id/complete`

### Commerce
`POST /api/v1/orders/quote`
`POST /api/v1/orders`
`GET /api/v1/orders/:id`
`POST /api/v1/orders/:id/cancel`

### Payments
`POST /api/v1/payments/create-intent`
`POST /api/v1/payments/:id/confirm`
`POST /api/v1/payments/webhook`
`POST /api/v1/refunds`

### Reviews / trust
`POST /api/v1/reviews`
`GET /api/v1/reviews`
`GET /api/v1/trust/:entityType/:entityId`

### Chat
`POST /api/v1/conversations`
`GET /api/v1/conversations`
`POST /api/v1/conversations/:id/messages`

### AI
`POST /api/v1/ai/search`
`POST /api/v1/ai/recommend`
`POST /api/v1/ai/moderate`
`POST /api/v1/ai/tasks`
`POST /api/v1/ai/approvals/:id/approve`

## Payment invariants
1. Client never writes `payments.status` as authoritative state.
2. Provider webhook must be authenticated/verified.
3. Webhooks are idempotent using provider + transaction/reference.
4. Amount/currency/order-or-booking linkage is checked server-side.
5. Only the server can mark capture/refund/settlement.
6. Every financial mutation is auditable.

## Booking invariants
`availability check → server price calculation → booking creation → payment intent → verified payment → confirmation`

The server is authoritative for availability, price, fees, commission, taxes and status transitions.

## AI risk model
- R0: read-only
- R1: low-risk automation
- R2: controlled business action
- R3: financial/security/admin-sensitive action; approval required
- R4: critical/destructive action; explicit approval + audit + additional safeguards

## Definition of done — backend foundation
- [x] PostgreSQL V1 schema
- [x] PostGIS
- [x] pgvector
- [x] audit foundation
- [x] RLS foundation
- [x] RLS hardening migration
- [x] API domains and invariants defined
- [ ] CITYFLOW Supabase project provisioned
- [ ] migrations applied to real project
- [ ] Edge Functions implemented
- [ ] payment provider connected
- [ ] web client connected
- [ ] integration/security tests
- [ ] production monitoring