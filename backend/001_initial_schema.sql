
-- CITYFLOW V1 — PostgreSQL / Supabase baseline migration
-- Version: 001_initial_schema
-- Target: PostgreSQL 15+ / Supabase
-- Note: authentication is delegated to Supabase Auth (auth.users).
-- This migration creates the application data model, RLS foundation,
-- audit triggers, indexes, and seed configuration for Martil.

begin;

create extension if not exists pgcrypto;
create extension if not exists postgis;
create extension if not exists vector;

create schema if not exists public;

-- ============================================================
-- ENUMS
-- ============================================================

do $$ begin
  create type public.user_status as enum ('active','pending','suspended','blocked','deleted');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.identity_status as enum ('unverified','pending','verified','rejected','expired');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.user_role as enum ('customer','business_owner','business_employee','moderator','support','finance','admin','super_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.city_status as enum ('active','inactive');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.listing_status as enum ('draft','pending_review','published','rejected','suspended','archived','deleted');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.verification_status as enum ('unverified','pending','verified','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.availability_status as enum ('available','unavailable','available_until','sold','rented','booked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.booking_status as enum ('pending','confirmed','in_progress','completed','cancelled','disputed','refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_status as enum ('pending','authorized','captured','failed','cancelled','partially_refunded','refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.refund_status as enum ('requested','approved','processing','completed','failed','rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum ('pending','confirmed','preparing','ready','out_for_delivery','completed','cancelled','disputed','refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.media_status as enum ('uploading','processing','ready','rejected','deleted');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.moderation_status as enum ('pending','approved','rejected','flagged');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_status as enum ('active','paused','disabled','error');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.ai_task_status as enum ('created','queued','running','waiting','review','approved','executed','completed','failed','blocked','cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.risk_level as enum ('r0','r1','r2','r3','r4');
exception when duplicate_object then null; end $$;

-- ============================================================
-- CORE: CITIES / LOCATIONS / CATEGORIES
-- ============================================================

create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  country_code char(2) not null,
  name text not null,
  slug text not null unique,
  region text,
  timezone text not null default 'Africa/Casablanca',
  currency char(3) not null default 'MAD',
  latitude numeric(9,6),
  longitude numeric(9,6),
  status public.city_status not null default 'inactive',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.neighborhoods (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete restrict,
  name text not null,
  slug text not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  boundary geography(multipolygon,4326),
  status public.city_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(city_id, slug)
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities(id) on delete restrict,
  neighborhood_id uuid references public.neighborhoods(id) on delete set null,
  address text,
  postal_code text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  geolocation geography(point,4326),
  visibility_level text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  icon text,
  type text,
  sort_order integer not null default 0,
  status public.city_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.category_attributes (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name text not null,
  slug text not null,
  data_type text not null,
  required boolean not null default false,
  filterable boolean not null default false,
  searchable boolean not null default false,
  options jsonb not null default '{}'::jsonb,
  validation_rules jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(category_id, slug)
);

-- ============================================================
-- IDENTITY / USERS
-- ============================================================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  phone text,
  first_name text,
  last_name text,
  display_name text,
  avatar_url text,
  preferred_language text not null default 'fr',
  country_code char(2),
  status public.user_status not null default 'active',
  email_verified boolean not null default false,
  phone_verified boolean not null default false,
  identity_status public.identity_status not null default 'unverified',
  trust_score numeric(5,2) not null default 0 check (trust_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz,
  deleted_at timestamptz
);


-- Create the application user automatically when Supabase Auth creates a user.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    id, email, phone, preferred_language,
    email_verified, phone_verified
  )
  values (
    new.id,
    new.email,
    new.phone,
    coalesce(new.raw_user_meta_data->>'preferred_language', 'fr'),
    coalesce(new.email_confirmed_at is not null, false),
    coalesce(new.phone_confirmed_at is not null, false)
  )
  on conflict (id) do update set
    email = excluded.email,
    phone = excluded.phone,
    email_verified = excluded.email_verified,
    phone_verified = excluded.phone_verified,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create table if not exists public.user_profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  date_of_birth date,
  bio text,
  city_id uuid references public.cities(id) on delete set null,
  preferences jsonb not null default '{}'::jsonb,
  notification_preferences jsonb not null default '{}'::jsonb,
  privacy_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  unique(user_id, role)
);

create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id text,
  device_type text,
  ip_hash text,
  user_agent text,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz
);

create table if not exists public.identity_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  provider text,
  verification_type text not null,
  status public.identity_status not null default 'pending',
  country char(2),
  submitted_at timestamptz not null default now(),
  verified_at timestamptz,
  rejected_at timestamptz,
  expires_at timestamptz,
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb
);

-- ============================================================
-- BUSINESSES
-- ============================================================

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  category_id uuid references public.categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  logo_url text,
  cover_url text,
  phone text,
  email text,
  website text,
  status public.listing_status not null default 'draft',
  verification_status public.verification_status not null default 'unverified',
  trust_score numeric(5,2) not null default 0 check (trust_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'employee',
  permissions jsonb not null default '{}'::jsonb,
  status public.user_status not null default 'active',
  created_at timestamptz not null default now(),
  unique(business_id, user_id)
);

create table if not exists public.business_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  open_time time,
  close_time time,
  is_closed boolean not null default false,
  unique(business_id, day_of_week)
);

create table if not exists public.business_locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid not null references public.locations(id) on delete restrict,
  is_primary boolean not null default false,
  unique(business_id, location_id)
);

-- ============================================================
-- MARKETPLACE
-- ============================================================

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete restrict,
  owner_user_id uuid not null references public.users(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  category_id uuid not null references public.categories(id) on delete restrict,
  location_id uuid references public.locations(id) on delete set null,
  title text not null,
  slug text not null unique,
  description text,
  listing_type text not null,
  transaction_type text not null,
  price numeric(14,2) check (price >= 0),
  currency char(3) not null default 'MAD',
  price_unit text,
  status public.listing_status not null default 'draft',
  verification_status public.verification_status not null default 'unverified',
  availability_status public.availability_status not null default 'available',
  trust_score numeric(5,2) not null default 0 check (trust_score between 0 and 100),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.listing_attributes (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  attribute_id uuid not null references public.category_attributes(id) on delete restrict,
  value_text text,
  value_number numeric,
  value_boolean boolean,
  value_json jsonb,
  unique(listing_id, attribute_id)
);

create table if not exists public.listing_contacts (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  contact_type text not null,
  value text not null,
  is_public boolean not null default false
);

-- ============================================================
-- MEDIA / VIDEOS
-- ============================================================

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references public.users(id) on delete set null,
  storage_provider text not null default 'supabase_storage',
  storage_key text not null unique,
  media_type text not null,
  mime_type text,
  file_size bigint check (file_size >= 0),
  duration numeric(12,3),
  width integer,
  height integer,
  thumbnail_url text,
  status public.media_status not null default 'uploading',
  created_at timestamptz not null default now()
);

create table if not exists public.listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  media_type text not null,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  unique(listing_id, media_asset_id)
);

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  duration numeric(12,3),
  caption text,
  language text,
  moderation_status public.moderation_status not null default 'pending',
  quality_score numeric(5,2) check (quality_score between 0 and 100),
  content_score numeric(5,2) check (content_score between 0 and 100),
  views_count bigint not null default 0 check (views_count >= 0),
  likes_count bigint not null default 0 check (likes_count >= 0),
  comments_count bigint not null default 0 check (comments_count >= 0),
  shares_count bigint not null default 0 check (shares_count >= 0),
  saves_count bigint not null default 0 check (saves_count >= 0),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique(listing_id, media_asset_id)
);

create table if not exists public.user_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  listing_id uuid references public.listings(id) on delete set null,
  video_id uuid references public.videos(id) on delete set null,
  interaction_type text not null,
  session_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, listing_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  video_id uuid not null references public.videos(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  content text not null check (length(trim(content)) > 0),
  status public.moderation_status not null default 'pending',
  likes_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ============================================================
-- AVAILABILITY / PRICING / PROMOTIONS
-- ============================================================

create table if not exists public.availability_rules (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  status public.availability_status not null,
  quantity integer not null default 1 check (quantity >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table if not exists public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  start_at timestamptz not null,
  end_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now(),
  check (end_at > start_at)
);

create table if not exists public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  name text not null,
  pricing_type text not null,
  base_price numeric(14,2) not null check (base_price >= 0),
  currency char(3) not null default 'MAD',
  minimum_quantity integer,
  maximum_quantity integer,
  start_date date,
  end_date date,
  priority integer not null default 0,
  conditions jsonb not null default '{}'::jsonb,
  status public.city_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (maximum_quantity is null or minimum_quantity is null or maximum_quantity >= minimum_quantity),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  name text not null,
  promotion_type text not null,
  value numeric(14,2) not null check (value >= 0),
  currency char(3) default 'MAD',
  start_at timestamptz not null,
  end_at timestamptz not null,
  max_uses integer check (max_uses is null or max_uses >= 0),
  used_count integer not null default 0 check (used_count >= 0),
  status public.city_status not null default 'active',
  conditions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (end_at > start_at)
);

-- ============================================================
-- BOOKINGS / ORDERS
-- ============================================================

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.users(id) on delete restrict,
  business_id uuid not null references public.businesses(id) on delete restrict,
  listing_id uuid not null references public.listings(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  booking_reference text not null unique,
  start_at timestamptz not null,
  end_at timestamptz,
  quantity integer not null default 1 check (quantity > 0),
  guests_count integer check (guests_count is null or guests_count > 0),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  platform_fee numeric(14,2) not null default 0 check (platform_fee >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  total numeric(14,2) not null check (total >= 0),
  currency char(3) not null default 'MAD',
  status public.booking_status not null default 'pending',
  payment_status public.payment_status not null default 'pending',
  special_requests jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  completed_at timestamptz,
  check (end_at is null or end_at > start_at)
);

create table if not exists public.booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  description text not null,
  quantity integer not null default 1 check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.users(id) on delete restrict,
  business_id uuid not null references public.businesses(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  order_reference text not null unique,
  subtotal numeric(14,2) not null check (subtotal >= 0),
  discount numeric(14,2) not null default 0 check (discount >= 0),
  delivery_fee numeric(14,2) not null default 0 check (delivery_fee >= 0),
  platform_fee numeric(14,2) not null default 0 check (platform_fee >= 0),
  tax numeric(14,2) not null default 0 check (tax >= 0),
  total numeric(14,2) not null check (total >= 0),
  currency char(3) not null default 'MAD',
  order_type text not null,
  status public.order_status not null default 'pending',
  payment_status public.payment_status not null default 'pending',
  delivery_address_id uuid references public.locations(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  cancelled_at timestamptz
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete restrict,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  options jsonb not null default '{}'::jsonb
);

-- ============================================================
-- PAYMENTS / COMMISSIONS
-- ============================================================

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  provider text not null,
  provider_transaction_id text,
  amount numeric(14,2) not null check (amount >= 0),
  currency char(3) not null,
  status public.payment_status not null default 'pending',
  payment_method_type text,
  authorized_at timestamptz,
  captured_at timestamptz,
  failed_at timestamptz,
  refunded_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((booking_id is not null) <> (order_id is not null)),
  unique(provider, provider_transaction_id)
);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null,
  reason text not null,
  status public.refund_status not null default 'requested',
  provider_reference text,
  requested_by uuid references public.users(id) on delete set null,
  approved_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  city_id uuid references public.cities(id) on delete cascade,
  category_id uuid references public.categories(id) on delete cascade,
  transaction_type text not null,
  percentage numeric(7,4) not null default 0 check (percentage between 0 and 100),
  fixed_amount numeric(14,2) not null default 0 check (fixed_amount >= 0),
  currency char(3) not null default 'MAD',
  minimum_fee numeric(14,2),
  maximum_fee numeric(14,2),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  status public.city_status not null default 'active',
  check (effective_to is null or effective_to > effective_from)
);

create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  transaction_type text not null,
  booking_id uuid references public.bookings(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  business_id uuid not null references public.businesses(id) on delete restrict,
  gross_amount numeric(14,2) not null check (gross_amount >= 0),
  commission_amount numeric(14,2) not null check (commission_amount >= 0),
  net_amount numeric(14,2) not null check (net_amount >= 0),
  currency char(3) not null,
  status public.city_status not null default 'active',
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  check ((booking_id is not null) <> (order_id is not null))
);

-- ============================================================
-- REVIEWS / TRUST / DISPUTES / FRAUD
-- ============================================================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  author_user_id uuid not null references public.users(id) on delete restrict,
  target_user_id uuid references public.users(id) on delete restrict,
  listing_id uuid references public.listings(id) on delete restrict,
  business_id uuid references public.businesses(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  rating numeric(3,2) not null check (rating between 0 and 5),
  content text,
  status public.moderation_status not null default 'pending',
  verified_transaction boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (booking_id is not null or order_id is not null)
);

create table if not exists public.review_dimensions (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  dimension text not null,
  score numeric(5,2) not null check (score between 0 and 100),
  unique(review_id, dimension)
);

create table if not exists public.trust_scores (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  score numeric(5,2) not null check (score between 0 and 100),
  score_version integer not null default 1,
  identity_factor numeric(5,2),
  transaction_factor numeric(5,2),
  review_factor numeric(5,2),
  cancellation_factor numeric(5,2),
  dispute_factor numeric(5,2),
  behavior_factor numeric(5,2),
  calculated_at timestamptz not null default now()
);

create table if not exists public.trust_events (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  event_type text not null,
  impact numeric(8,4) not null,
  source text,
  reference_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.disputes (
  id uuid primary key default gen_random_uuid(),
  opened_by uuid not null references public.users(id) on delete restrict,
  customer_id uuid not null references public.users(id) on delete restrict,
  business_id uuid not null references public.businesses(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  payment_id uuid references public.payments(id) on delete restrict,
  reason text not null,
  description text,
  status text not null default 'open',
  priority text not null default 'normal',
  assigned_to uuid references public.users(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  check ((booking_id is not null) or (order_id is not null))
);

create table if not exists public.dispute_evidence (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes(id) on delete cascade,
  submitted_by uuid not null references public.users(id) on delete restrict,
  evidence_type text not null,
  media_asset_id uuid references public.media_assets(id) on delete set null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.fraud_cases (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  risk_score numeric(5,2) check (risk_score between 0 and 100),
  risk_level public.risk_level not null default 'r1',
  reason text,
  status text not null default 'open',
  assigned_to uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.fraud_signals (
  id uuid primary key default gen_random_uuid(),
  fraud_case_id uuid not null references public.fraud_cases(id) on delete cascade,
  signal_type text not null,
  severity text not null,
  confidence numeric(5,2) check (confidence between 0 and 100),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- CHAT / NOTIFICATIONS
-- ============================================================

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  listing_id uuid references public.listings(id) on delete set null,
  booking_id uuid references public.bookings(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key(conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete restrict,
  message_type text not null default 'text',
  content text,
  media_asset_id uuid references public.media_assets(id) on delete set null,
  status text not null default 'sent',
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

-- ============================================================
-- CITYPASS / ANALYTICS
-- ============================================================

create table if not exists public.loyalty_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  points_balance bigint not null default 0 check (points_balance >= 0),
  lifetime_points bigint not null default 0 check (lifetime_points >= 0),
  tier text not null default 'standard',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.loyalty_transactions (
  id uuid primary key default gen_random_uuid(),
  loyalty_account_id uuid not null references public.loyalty_accounts(id) on delete cascade,
  type text not null,
  points bigint not null,
  reference_type text,
  reference_id uuid,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  anonymous_id text,
  user_id uuid references public.users(id) on delete set null,
  session_id text,
  event_name text not null,
  entity_type text,
  entity_id uuid,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- AI OPERATING SYSTEM
-- ============================================================

create table if not exists public.ai_agents (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  agent_type text not null,
  version text not null default '1.0.0',
  status public.ai_status not null default 'active',
  risk_level public.risk_level not null default 'r1',
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_tasks (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid not null references public.ai_agents(id) on delete restrict,
  parent_task_id uuid references public.ai_tasks(id) on delete set null,
  task_type text not null,
  priority integer not null default 100,
  risk_level public.risk_level not null default 'r1',
  input jsonb not null default '{}'::jsonb,
  expected_output jsonb not null default '{}'::jsonb,
  result jsonb,
  status public.ai_task_status not null default 'created',
  requires_approval boolean not null default false,
  approved_by uuid references public.users(id) on delete set null,
  started_at timestamptz,
  completed_at timestamptz,
  failed_at timestamptz,
  error_code text,
  error_message text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  source text not null,
  entity_type text,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  processed boolean not null default false,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists public.ai_memory (
  id uuid primary key default gen_random_uuid(),
  scope text not null,
  owner_type text,
  owner_id uuid,
  memory_type text not null,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  importance numeric(5,2) check (importance between 0 and 100),
  confidence numeric(5,2) check (confidence between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.ai_knowledge (
  id uuid primary key default gen_random_uuid(),
  source_type text,
  source_id uuid,
  title text not null,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  embedding vector(1536),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_approvals (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.ai_tasks(id) on delete cascade,
  requested_by_agent_id uuid not null references public.ai_agents(id) on delete restrict,
  approval_type text not null,
  risk_level public.risk_level not null,
  description text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  approved_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- ============================================================
-- ADMIN / AUDIT
-- ============================================================

create table if not exists public.system_settings (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  value jsonb not null default '{}'::jsonb,
  environment text not null default 'production',
  description text,
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(key, environment)
);

create table if not exists public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  enabled boolean not null default false,
  environment text not null default 'production',
  city_id uuid references public.cities(id) on delete cascade,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(key, environment, city_id)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_type text not null,
  actor_id uuid,
  action text not null,
  entity_type text,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_hash text,
  request_id text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- FUNCTIONS / TRIGGERS
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
as $$
begin
  new.updated_at = now();
  return new;