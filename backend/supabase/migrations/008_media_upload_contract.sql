create table if not exists public.media_uploads (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete cascade,
  storage_key text not null unique,
  media_type text not null check (media_type in ('image','video')),
  mime_type text not null,
  file_size bigint,
  status text not null default 'pending_moderation'
    check (status in ('pending_upload','uploaded','pending_moderation','approved','rejected')),
  created_at timestamptz not null default now()
);
alter table public.media_uploads enable row level security;
drop policy if exists media_uploads_owner_select on public.media_uploads;
create policy media_uploads_owner_select on public.media_uploads
for select to authenticated using (owner_user_id=auth.uid());
drop policy if exists media_uploads_owner_insert on public.media_uploads;
create policy media_uploads_owner_insert on public.media_uploads
for insert to authenticated with check (owner_user_id=auth.uid());
create index if not exists idx_media_uploads_owner_listing
on public.media_uploads(owner_user_id,listing_id);