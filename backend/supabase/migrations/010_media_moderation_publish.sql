create or replace function public.cityflow_moderate_media(
  p_upload_id uuid,
  p_decision text,
  p_quality_score numeric default null,
  p_content_score numeric default null,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  u public.media_uploads%rowtype;
  asset_id uuid;
begin
  select * into u from public.media_uploads where id=p_upload_id for update;
  if not found then raise exception 'MEDIA_UPLOAD_NOT_FOUND'; end if;
  if p_decision not in ('approve','reject') then raise exception 'INVALID_MODERATION_DECISION'; end if;

  if p_decision='reject' then
    update public.media_uploads set status='rejected' where id=p_upload_id;
    return jsonb_build_object('upload_id',p_upload_id,'status','rejected','reason',p_reason);
  end if;

  insert into public.media_assets(
    owner_user_id,storage_provider,storage_key,media_type,mime_type,file_size,status
  ) values (
    u.owner_user_id,'supabase_storage',u.storage_key,u.media_type,u.mime_type,u.file_size,'ready'
  ) returning id into asset_id;

  insert into public.listing_media(listing_id,media_asset_id,media_type,sort_order,is_primary)
  values(u.listing_id,asset_id,u.media_type,0,true)
  on conflict (listing_id,media_asset_id) do nothing;

  if u.media_type='video' then
    insert into public.videos(listing_id,media_asset_id,moderation_status,quality_score,content_score,published_at)
    values(u.listing_id,asset_id,'approved',p_quality_score,p_content_score,now())
    on conflict (listing_id,media_asset_id) do update set
      moderation_status='approved',
      quality_score=excluded.quality_score,
      content_score=excluded.content_score,
      published_at=coalesce(public.videos.published_at,excluded.published_at);
  end if;

  update public.media_uploads set status='approved' where id=p_upload_id;

  update public.listings
  set status='published',
      published_at=coalesce(published_at,now()),
      verification_status='verified'
  where id=u.listing_id and status='pending_review';

  return jsonb_build_object('upload_id',p_upload_id,'status','approved','media_asset_id',asset_id);
end;
$$;

revoke all on function public.cityflow_moderate_media(uuid,text,numeric,numeric,text) from public,anon,authenticated;
grant execute on function public.cityflow_moderate_media(uuid,text,numeric,numeric,text) to service_role;

create or replace function public.cityflow_moderate_media_reject(
  p_upload_id uuid,
  p_reason text default null
) returns jsonb
language sql
security definer
set search_path=public
as $$
  select public.cityflow_moderate_media(p_upload_id,'reject',null,null,p_reason);
$$;
revoke all on function public.cityflow_moderate_media_reject(uuid,text) from public,anon,authenticated;
grant execute on function public.cityflow_moderate_media_reject(uuid,text) to service_role;

create index if not exists idx_media_uploads_moderation_queue
on public.media_uploads(status,created_at);
create index if not exists idx_media_assets_storage_key
on public.media_assets(storage_key);
create unique index if not exists videos_media_asset_uq
on public.videos(listing_id,media_asset_id);