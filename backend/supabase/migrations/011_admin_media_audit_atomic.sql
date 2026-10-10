-- Atomic media moderation and audit trail. The service-only RPC is called after
-- the Edge Function authenticates the user and validates admin/moderator roles.
create or replace function public.cityflow_moderate_media_audited(
  p_upload_id uuid,
  p_decision text,
  p_quality_score numeric default null,
  p_content_score numeric default null,
  p_reason text default null,
  p_actor_id uuid default null,
  p_actor_type text default 'moderator'
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
  v_after jsonb;
  v_result jsonb;
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
begin
  if p_actor_id is null or p_actor_type not in ('admin','moderator') then
    raise exception 'INVALID_AUDIT_ACTOR' using errcode='22023';
  end if;
  if p_decision not in ('approve','reject') then
    raise exception 'INVALID_DECISION' using errcode='22023';
  end if;
  if p_decision='reject' and length(coalesce(v_reason,'')) < 8 then
    raise exception 'REASON_REQUIRED_MIN_8_CHARS' using errcode='22023';
  end if;

  select to_jsonb(m) into v_before
  from public.media_uploads m where m.id=p_upload_id for update;
  if v_before is null then raise exception 'UPLOAD_NOT_FOUND' using errcode='P0002'; end if;

  v_result := public.cityflow_moderate_media(
    p_upload_id, p_decision, p_quality_score, p_content_score, v_reason
  );

  select to_jsonb(m) into v_after
  from public.media_uploads m where m.id=p_upload_id;

  insert into public.audit_logs(
    actor_type,actor_id,action,entity_type,entity_id,before_data,after_data,request_id
  ) values (
    p_actor_type,p_actor_id,'media.'||p_decision,'media_upload',p_upload_id,
    jsonb_build_object('record',v_before,'reason',v_reason),
    jsonb_build_object('record',v_after,'result',v_result,'reason',v_reason),
    'admin-center'
  );

  return v_result;
end;
$$;

revoke all on function public.cityflow_moderate_media_audited(uuid,text,numeric,numeric,text,uuid,text) from public, anon, authenticated;
grant execute on function public.cityflow_moderate_media_audited(uuid,text,numeric,numeric,text,uuid,text) to service_role;
