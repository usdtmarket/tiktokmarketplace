-- CITYFLOW: make the live Admin Center RPC definitions reproducible.
-- Recovered from the live project on 2026-10-12. Review against a clean database
-- before applying anywhere other than the already-migrated production project.

CREATE OR REPLACE FUNCTION private.cityflow_admin_action(
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_reason text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_before jsonb;
  v_after jsonb;
  v_reason text := nullif(btrim(coalesce(p_reason,'')),'');
  v_target_admin boolean := false;
BEGIN
  IF v_actor IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING errcode='42501';
  END IF;
  IF p_entity_id IS NULL OR p_entity_type NOT IN ('listing','review','video','business','dispute','fraud_case','user') THEN
    RAISE EXCEPTION 'INVALID_ADMIN_TARGET' USING errcode='22023';
  END IF;
  IF p_action IN ('reject','suspend','resolve','dismiss') AND length(coalesce(v_reason,'')) < 8 THEN
    RAISE EXCEPTION 'REASON_REQUIRED_MIN_8_CHARS' USING errcode='22023';
  END IF;

  CASE p_entity_type
  WHEN 'listing' THEN
    SELECT to_jsonb(l) INTO v_before FROM public.listings l WHERE l.id=p_entity_id AND l.deleted_at IS NULL FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'LISTING_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action='approve' THEN
      UPDATE public.listings SET status='published', published_at=coalesce(published_at,now()), updated_at=now() WHERE id=p_entity_id;
    ELSIF p_action='reject' THEN
      UPDATE public.listings SET status='rejected', updated_at=now() WHERE id=p_entity_id;
    ELSE RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    SELECT to_jsonb(l) INTO v_after FROM public.listings l WHERE l.id=p_entity_id;
  WHEN 'review' THEN
    SELECT to_jsonb(r) INTO v_before FROM public.reviews r WHERE r.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'REVIEW_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action NOT IN ('approve','reject') THEN RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    UPDATE public.reviews SET status=CASE WHEN p_action='approve' THEN 'approved'::public.moderation_status ELSE 'rejected'::public.moderation_status END, updated_at=now() WHERE id=p_entity_id;
    SELECT to_jsonb(r) INTO v_after FROM public.reviews r WHERE r.id=p_entity_id;
  WHEN 'video' THEN
    SELECT to_jsonb(v) INTO v_before FROM public.videos v WHERE v.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'VIDEO_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action NOT IN ('approve','reject') THEN RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    UPDATE public.videos SET moderation_status=CASE WHEN p_action='approve' THEN 'approved'::public.moderation_status ELSE 'rejected'::public.moderation_status END WHERE id=p_entity_id;
    SELECT to_jsonb(v) INTO v_after FROM public.videos v WHERE v.id=p_entity_id;
  WHEN 'business' THEN
    SELECT to_jsonb(b) INTO v_before FROM public.businesses b WHERE b.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'BUSINESS_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action NOT IN ('verify','reject') THEN RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    UPDATE public.businesses SET verification_status=CASE WHEN p_action='verify' THEN 'verified'::public.verification_status ELSE 'rejected'::public.verification_status END, updated_at=now() WHERE id=p_entity_id;
    SELECT to_jsonb(b) INTO v_after FROM public.businesses b WHERE b.id=p_entity_id;
  WHEN 'dispute' THEN
    SELECT to_jsonb(d) INTO v_before FROM public.disputes d WHERE d.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'DISPUTE_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action='assign_self' THEN
      UPDATE public.disputes SET assigned_to=v_actor, updated_at=now() WHERE id=p_entity_id AND status NOT IN ('resolved','closed','rejected');
      IF NOT found THEN RAISE EXCEPTION 'DISPUTE_ALREADY_CLOSED' USING errcode='22023'; END IF;
    ELSIF p_action='resolve' THEN
      UPDATE public.disputes SET status='resolved', resolution=v_reason, resolved_at=now(), assigned_to=coalesce(assigned_to,v_actor), updated_at=now() WHERE id=p_entity_id AND status NOT IN ('resolved','closed','rejected');
      IF NOT found THEN RAISE EXCEPTION 'DISPUTE_ALREADY_CLOSED' USING errcode='22023'; END IF;
    ELSE RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    SELECT to_jsonb(d) INTO v_after FROM public.disputes d WHERE d.id=p_entity_id;
  WHEN 'fraud_case' THEN
    SELECT to_jsonb(f) INTO v_before FROM public.fraud_cases f WHERE f.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'FRAUD_CASE_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_action='assign_self' THEN
      UPDATE public.fraud_cases SET assigned_to=v_actor WHERE id=p_entity_id AND status NOT IN ('resolved','closed','dismissed');
      IF NOT found THEN RAISE EXCEPTION 'CASE_ALREADY_CLOSED' USING errcode='22023'; END IF;
    ELSIF p_action IN ('resolve','dismiss') THEN
      UPDATE public.fraud_cases SET status=CASE WHEN p_action='resolve' THEN 'resolved' ELSE 'dismissed' END, resolved_at=now(), assigned_to=coalesce(assigned_to,v_actor), reason=left(coalesce(reason,'')||' | Decision admin: '||v_reason,1000) WHERE id=p_entity_id AND status NOT IN ('resolved','closed','dismissed');
      IF NOT found THEN RAISE EXCEPTION 'CASE_ALREADY_CLOSED' USING errcode='22023'; END IF;
    ELSE RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    SELECT to_jsonb(f) INTO v_after FROM public.fraud_cases f WHERE f.id=p_entity_id;
  WHEN 'user' THEN
    SELECT to_jsonb(u) INTO v_before FROM public.users u WHERE u.id=p_entity_id FOR UPDATE;
    IF v_before IS NULL THEN RAISE EXCEPTION 'USER_NOT_FOUND' USING errcode='P0002'; END IF;
    IF p_entity_id=v_actor THEN RAISE EXCEPTION 'CANNOT_SUSPEND_SELF' USING errcode='22023'; END IF;
    SELECT exists(SELECT 1 FROM public.user_roles ur WHERE ur.user_id=p_entity_id AND ur.role IN ('admin','super_admin') AND (ur.expires_at IS NULL OR ur.expires_at>now())) INTO v_target_admin;
    IF v_target_admin AND NOT exists(SELECT 1 FROM public.user_roles ur WHERE ur.user_id=v_actor AND ur.role='super_admin' AND (ur.expires_at IS NULL OR ur.expires_at>now())) THEN
      RAISE EXCEPTION 'SUPER_ADMIN_REQUIRED' USING errcode='42501';
    END IF;
    IF p_action='suspend' THEN
      UPDATE public.users SET status='suspended', updated_at=now() WHERE id=p_entity_id;
    ELSIF p_action='reactivate' THEN
      UPDATE public.users SET status='active', updated_at=now() WHERE id=p_entity_id AND status IN ('suspended','blocked');
      IF NOT found THEN RAISE EXCEPTION 'USER_NOT_SUSPENDED' USING errcode='22023'; END IF;
    ELSE RAISE EXCEPTION 'ACTION_NOT_ALLOWED' USING errcode='22023'; END IF;
    SELECT to_jsonb(u) INTO v_after FROM public.users u WHERE u.id=p_entity_id;
  END CASE;

  INSERT INTO public.audit_logs(actor_type,actor_id,action,entity_type,entity_id,before_data,after_data,request_id)
  VALUES('admin',v_actor,p_entity_type||'.'||p_action,p_entity_type,p_entity_id,
    jsonb_build_object('record',v_before,'reason',v_reason),
    jsonb_build_object('record',v_after,'reason',v_reason), 'admin-center');
  RETURN jsonb_build_object('ok',true,'entity_type',p_entity_type,'entity_id',p_entity_id,'action',p_action,'updated_at',now());
END;
$function$;

CREATE OR REPLACE FUNCTION private.cityflow_admin_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN RAISE EXCEPTION 'ADMIN_REQUIRED' USING errcode='42501'; END IF;
  SELECT jsonb_build_object(
    'generated_at',now(),
    'metrics',jsonb_build_object(
      'users',(SELECT count(*) FROM public.users WHERE status <> 'deleted'),
      'users_pending',(SELECT count(*) FROM public.users WHERE status='pending'),
      'businesses',(SELECT count(*) FROM public.businesses),
      'businesses_pending',(SELECT count(*) FROM public.businesses WHERE verification_status='pending'),
      'listings',(SELECT count(*) FROM public.listings WHERE deleted_at IS NULL),
      'listings_pending',(SELECT count(*) FROM public.listings WHERE deleted_at IS NULL AND status IN ('pending_review','draft')),
      'videos_pending',(SELECT count(*) FROM public.videos WHERE moderation_status='pending'),
      'media_pending',(SELECT count(*) FROM public.media_uploads WHERE status='pending_moderation'),
      'reviews_pending',(SELECT count(*) FROM public.reviews WHERE status='pending'),
      'transactions_open',(SELECT count(*) FROM public.bookings WHERE status IN ('pending','confirmed','in_progress'))+(SELECT count(*) FROM public.orders WHERE status IN ('pending','confirmed','preparing','ready','out_for_delivery')),
      'disputes_open',(SELECT count(*) FROM public.disputes WHERE status NOT IN ('resolved','closed','rejected')),
      'fraud_open',(SELECT count(*) FROM public.fraud_cases WHERE status NOT IN ('resolved','closed','dismissed'))),
    'queues',jsonb_build_object(
      'reviews',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT r.id,r.rating,left(coalesce(r.content,''),240) content,r.status,r.verified_transaction,r.created_at,r.business_id,r.listing_id FROM public.reviews r WHERE r.status='pending' ORDER BY r.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'listings',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT l.id,l.title,l.status,l.verification_status,l.created_at,l.business_id FROM public.listings l WHERE l.deleted_at IS NULL AND l.status IN ('pending_review','draft') ORDER BY l.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'businesses',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT b.id,b.name,b.status,b.verification_status,b.created_at FROM public.businesses b WHERE b.verification_status='pending' ORDER BY b.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'users',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT u.id,coalesce(u.display_name,concat_ws(' ',u.first_name,u.last_name),'Utilisateur') display_name,u.status,u.identity_status,u.trust_score,u.created_at FROM public.users u WHERE u.status IN ('active','pending','suspended','blocked') AND u.id<>auth.uid() ORDER BY u.created_at DESC LIMIT 30)x),'[]'::jsonb),
      'media',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT m.id,m.media_type,m.status,m.created_at,m.listing_id FROM public.media_uploads m WHERE m.status='pending_moderation' ORDER BY m.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'videos',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT v.id,v.listing_id,v.caption,v.moderation_status,v.created_at FROM public.videos v WHERE v.moderation_status='pending' ORDER BY v.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'disputes',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT d.id,d.reason,left(coalesce(d.description,''),240) description,d.status,d.priority,d.created_at,d.booking_id,d.order_id,d.assigned_to FROM public.disputes d WHERE d.status NOT IN ('resolved','closed','rejected') ORDER BY CASE d.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,d.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'fraud',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT f.id,f.entity_type,f.risk_score,f.risk_level,f.reason,f.status,f.created_at,f.assigned_to FROM public.fraud_cases f WHERE f.status NOT IN ('resolved','closed','dismissed') ORDER BY f.risk_score DESC NULLS LAST,f.created_at ASC LIMIT 30)x),'[]'::jsonb),
      'audit',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT a.id,a.actor_type,a.action,a.entity_type,a.entity_id,a.created_at FROM public.audit_logs a ORDER BY a.created_at DESC LIMIT 30)x),'[]'::jsonb),
      'payments',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM (SELECT p.id,p.provider,p.amount,p.currency,p.status,p.created_at,p.booking_id,p.order_id FROM public.payments p WHERE p.status IN ('pending','authorized','failed') ORDER BY p.created_at DESC LIMIT 30)x),'[]'::jsonb)
    )) INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cityflow_admin_action(p_entity_type text,p_entity_id uuid,p_action text,p_reason text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE sql SET search_path TO 'public','private'
AS $function$ SELECT private.cityflow_admin_action(p_entity_type,p_entity_id,p_action,p_reason); $function$;

CREATE OR REPLACE FUNCTION public.cityflow_admin_overview()
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public','private'
AS $function$ SELECT private.cityflow_admin_overview(); $function$;

REVOKE ALL ON FUNCTION public.cityflow_admin_action(text,uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cityflow_admin_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cityflow_admin_action(text,uuid,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cityflow_admin_overview() TO authenticated, service_role;
REVOKE ALL ON FUNCTION private.cityflow_admin_action(text,uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.cityflow_admin_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.cityflow_admin_action(text,uuid,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.cityflow_admin_overview() TO authenticated, service_role;
