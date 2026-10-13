-- CITYFLOW V1 — 002 RLS / SECURITY HARDENING
-- PostgreSQL 15+ / Supabase
-- Security boundary: public discovery read-only; customer/business writes scoped;
-- payment, refund, commission, fraud, trust, AI execution and audit are server controlled.

begin;

create or replace function public.is_admin()
returns boolean language sql security definer set search_path=public stable as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id=auth.uid()
      and ur.role in ('admin','super_admin')
      and (ur.expires_at is null or ur.expires_at>now())
  );
$$;

create or replace function public.is_business_member(p_business_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select exists (
    select 1 from public.businesses b
    left join public.business_members bm on bm.business_id=b.id
      and bm.user_id=auth.uid() and bm.status='active'
    where b.id=p_business_id and (b.owner_user_id=auth.uid() or bm.user_id is not null)
  );
$$;

create or replace function public.can_manage_business(p_business_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select public.is_admin() or exists (
    select 1 from public.businesses b
    left join public.business_members bm on bm.business_id=b.id
      and bm.user_id=auth.uid() and bm.status='active'
    where b.id=p_business_id and (
      b.owner_user_id=auth.uid()
      or (bm.user_id is not null and bm.role in ('owner','manager','admin'))
    )
  );
$$;

create or replace function public.can_manage_listing(p_listing_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select public.is_admin() or exists (
    select 1 from public.listings l
    where l.id=p_listing_id and (
      l.owner_user_id=auth.uid()
      or (l.business_id is not null and public.can_manage_business(l.business_id))
    )
  );
$$;

create or replace function public.can_view_booking(p_booking_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select public.is_admin() or exists (
    select 1 from public.bookings b
    where b.id=p_booking_id and (
      b.customer_id=auth.uid() or public.is_business_member(b.business_id)
    )
  );
$$;

create or replace function public.can_view_order(p_order_id uuid)
returns boolean language sql security definer set search_path=public stable as $$
  select public.is_admin() or exists (
    select 1 from public.orders o
    where o.id=p_order_id and (
      o.customer_id=auth.uid() or public.is_business_member(o.business_id)
    )
  );
$$;

-- Public discovery
create policy cities_public_select on public.cities for select to anon,authenticated using(status='active');
create policy neighborhoods_public_select on public.neighborhoods for select to anon,authenticated using(status='active');
create policy locations_public_select on public.locations for select to anon,authenticated using(visibility_level='public');
create policy categories_public_select on public.categories for select to anon,authenticated using(status='active');
create policy category_attributes_public_select on public.category_attributes for select to anon,authenticated using(exists(select 1 from public.categories c where c.id=category_attributes.category_id and c.status='active'));
create policy businesses_public_select on public.businesses for select to anon,authenticated using(status='published' and verification_status in('verified','unverified'));
create policy listings_public_select_v2 on public.listings for select to anon,authenticated using(status='published' and deleted_at is null);
create policy listing_media_public_select on public.listing_media for select to anon,authenticated using(exists(select 1 from public.listings l where l.id=listing_media.listing_id and l.status='published' and l.deleted_at is null));
create policy videos_public_select on public.videos for select to anon,authenticated using(moderation_status='approved' and exists(select 1 from public.listings l where l.id=videos.listing_id and l.status='published' and l.deleted_at is null));
create policy media_assets_public_select on public.media_assets for select to anon,authenticated using(status='ready' and exists(select 1 from public.listing_media lm join public.listings l on l.id=lm.listing_id where lm.media_asset_id=media_assets.id and l.status='published' and l.deleted_at is null));
create policy business_hours_public_select on public.business_hours for select to anon,authenticated using(exists(select 1 from public.businesses b where b.id=business_hours.business_id and b.status='published'));
create policy business_locations_public_select on public.business_locations for select to anon,authenticated using(exists(select 1 from public.businesses b where b.id=business_locations.business_id and b.status='published'));
create policy listing_contacts_public_select on public.listing_contacts for select to anon,authenticated using(is_public and exists(select 1 from public.listings l where l.id=listing_contacts.listing_id and l.status='published' and l.deleted_at is null));
create policy availability_public_select on public.availability_rules for select to anon,authenticated using(exists(select 1 from public.listings l where l.id=availability_rules.listing_id and l.status='published'));
create policy pricing_public_select on public.pricing_rules for select to anon,authenticated using(exists(select 1 from public.listings l where l.id=pricing_rules.listing_id and l.status='published'));
create policy promotions_public_select on public.promotions for select to anon,authenticated using(status='active' and start_at<=now() and end_at>now());
create policy comments_public_select on public.comments for select to anon,authenticated using(status='approved' and deleted_at is null);
create policy reviews_public_select on public.reviews for select to anon,authenticated using(status='approved');
create policy trust_scores_public_select on public.trust_scores for select to anon,authenticated using(entity_type in('business','listing','user'));

-- User-owned data
create policy users_self_select on public.users for select to authenticated using(id=auth.uid() or public.is_admin());
-- Direct users UPDATE is intentionally not granted; mutable profile data belongs in user_profiles.
create policy profiles_self_all on public.user_profiles for all to authenticated using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());
create policy user_roles_self_select on public.user_roles for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy sessions_self_all on public.user_sessions for all to authenticated using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());
create policy identity_self_select on public.identity_verifications for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy identity_self_insert on public.identity_verifications for insert to authenticated with check(user_id=auth.uid());
create policy favorites_self_all_v2 on public.favorites for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy interactions_self_insert on public.user_interactions for insert to authenticated with check(user_id=auth.uid());
create policy comments_self_insert on public.comments for insert to authenticated with check(user_id=auth.uid());
create policy comments_self_update on public.comments for update to authenticated using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin());

-- Business boundary
create policy business_owner_insert on public.businesses for insert to authenticated with check(owner_user_id=auth.uid());
create policy business_member_select_v2 on public.businesses for select to authenticated using((status='published' and verification_status in('verified','unverified')) or owner_user_id=auth.uid() or public.is_business_member(id) or public.is_admin());
create policy business_manage_update on public.businesses for update to authenticated using(public.can_manage_business(id)) with check(public.can_manage_business(id));
create policy business_manage_delete on public.businesses for delete to authenticated using(public.is_admin() or owner_user_id=auth.uid());
create policy business_members_self_select on public.business_members for select to authenticated using(user_id=auth.uid() or public.can_manage_business(business_id));
create policy business_members_manage on public.business_members for all to authenticated using(public.can_manage_business(business_id)) with check(public.can_manage_business(business_id));
create policy business_hours_manage on public.business_hours for all to authenticated using(public.can_manage_business(business_id)) with check(public.can_manage_business(business_id));
create policy business_locations_manage on public.business_locations for all to authenticated using(public.can_manage_business(business_id)) with check(public.can_manage_business(business_id));

-- Listing/content management
create policy listings_owner_insert on public.listings for insert to authenticated with check(owner_user_id=auth.uid() and (business_id is null or public.is_business_member(business_id)));
create policy listings_owner_manage on public.listings for update to authenticated using(public.can_manage_listing(id)) with check(public.can_manage_listing(id));
create policy listings_owner_delete on public.listings for delete to authenticated using(public.can_manage_listing(id));
create policy listing_attributes_manage on public.listing_attributes for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy listing_contacts_manage on public.listing_contacts for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy listing_media_manage on public.listing_media for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy videos_manage on public.videos for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy availability_manage on public.availability_rules for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy availability_blocks_manage on public.availability_blocks for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy pricing_manage on public.pricing_rules for all to authenticated using(public.can_manage_listing(listing_id)) with check(public.can_manage_listing(listing_id));
create policy promotions_manage on public.promotions for all to authenticated using(public.can_manage_business(business_id)) with check(public.can_manage_business(business_id));

-- Booking/order visibility. Creation and status transitions should move through server RPCs/Edge Functions.
create policy bookings_participant_select on public.bookings for select to authenticated using(public.can_view_booking(id));
create policy bookings_customer_insert on public.bookings for insert to authenticated with check(customer_id=auth.uid() and exists(select 1 from public.listings l where l.id=bookings.listing_id and l.status='published' and l.business_id=bookings.business_id));
create policy bookings_participant_update on public.bookings for update to authenticated using(customer_id=auth.uid() or public.can_manage_business(business_id)) with check(customer_id=auth.uid() or public.can_manage_business(business_id));
create policy booking_items_participant_select on public.booking_items for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_items.booking_id and public.can_view_booking(b.id)));
create policy orders_participant_select on public.orders for select to authenticated using(public.can_view_order(id));
create policy orders_customer_insert on public.orders for insert to authenticated with check(customer_id=auth.uid());
create policy orders_participant_update on public.orders for update to authenticated using(customer_id=auth.uid() or public.can_manage_business(business_id)) with check(customer_id=auth.uid() or public.can_manage_business(business_id));
create policy order_items_participant_select on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_items.order_id and public.can_view_order(o.id)));

-- Financial records: no client-side write policies.
create policy payments_self_select on public.payments for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy refunds_admin_select on public.refunds for select to authenticated using(public.is_admin());
create policy commissions_admin_select on public.commissions for select to authenticated using(public.is_admin() or exists(select 1 from public.businesses b where b.id=commissions.business_id and b.owner_user_id=auth.uid()));
create policy commission_rules_admin_select on public.commission_rules for select to authenticated using(public.is_admin());

-- Reviews: only verified completed transactions may create.
create policy reviews_author_insert on public.reviews for insert to authenticated with check(
  author_user_id=auth.uid() and (
    (booking_id is not null and exists(select 1 from public.bookings b where b.id=reviews.booking_id and b.customer_id=auth.uid() and b.status='completed'))
    or (order_id is not null and exists(select 1 from public.orders o where o.id=reviews.order_id and o.customer_id=auth.uid() and o.status='completed'))
  )
);
create policy reviews_author_update on public.reviews for update to authenticated using(author_user_id=auth.uid() or public.is_admin()) with check(author_user_id=auth.uid() or public.is_admin());
create policy review_dimensions_select on public.review_dimensions for select to authenticated using(exists(select 1 from public.reviews r where r.id=review_dimensions.review_id and (r.author_user_id=auth.uid() or r.status='approved')));

-- Chat
create policy conversation_members_self_select on public.conversation_members for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy messages_member_select on public.messages for select to authenticated using(exists(select 1 from public.conversation_members cm where cm.conversation_id=messages.conversation_id and cm.user_id=auth.uid()));
create policy messages_member_insert on public.messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from public.conversation_members cm where cm.conversation_id=messages.conversation_id and cm.user_id=auth.uid()));
create policy messages_member_update on public.messages for update to authenticated using(sender_id=auth.uid() or public.is_admin()) with check(sender_id=auth.uid() or public.is_admin());
create policy notifications_self_select_v2 on public.notifications for select to authenticated using(user_id=auth.uid());

-- CityPass / analytics
create policy loyalty_self_select_v2 on public.loyalty_accounts for select to authenticated using(user_id=auth.uid() or public.is_admin());
create policy loyalty_transactions_self_select on public.loyalty_transactions for select to authenticated using(exists(select 1 from public.loyalty_accounts la where la.id=loyalty_transactions.loyalty_account_id and (la.user_id=auth.uid() or public.is_admin())));
create policy analytics_insert on public.analytics_events for insert to anon,authenticated with check(user_id is null or user_id=auth.uid());

-- AI/admin: server controlled.
create policy ai_agents_admin_select on public.ai_agents for select to authenticated using(public.is_admin());
create policy ai_tasks_admin_all on public.ai_tasks for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy ai_approvals_admin_all on public.ai_approvals for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy system_settings_admin_all on public.system_settings for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy feature_flags_admin_all on public.feature_flags for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy audit_logs_admin_select on public.audit_logs for select to authenticated using(public.is_admin());

-- Column-level integrity guard: RLS controls WHO can touch a row;
-- these triggers control WHICH protected fields may change from the client.
create or replace function public.prevent_protected_field_changes()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(auth.role(),'') <> 'service_role' and not public.is_admin() then
    if tg_table_name='users' then
      new.id := old.id;
      new.status := old.status;
      new.email_verified := old.email_verified;
      new.phone_verified := old.phone_verified;
      new.identity_status := old.identity_status;
      new.trust_score := old.trust_score;
      new.created_at := old.created_at;
      new.last_login_at := old.last_login_at;
      new.deleted_at := old.deleted_at;
    elsif tg_table_name='businesses' then
      new.owner_user_id := old.owner_user_id;
      new.city_id := old.city_id;
      new.verification_status := old.verification_status;
      new.trust_score := old.trust_score;
      new.status := old.status;
      new.created_at := old.created_at;
    elsif tg_table_name='listings' then
      new.owner_user_id := old.owner_user_id;
      new.business_id := old.business_id;
      new.city_id := old.city_id;
      new.category_id := old.category_id;
      new.verification_status := old.verification_status;
      new.trust_score := old.trust_score;
      new.status := old.status;
      new.availability_status := old.availability_status;
      new.published_at := old.published_at;
      new.deleted_at := old.deleted_at;
      new.created_at := old.created_at;
    elsif tg_table_name='bookings' then
      new.customer_id := old.customer_id;
      new.business_id := old.business_id;
      new.listing_id := old.listing_id;
      new.city_id := old.city_id;
      new.booking_reference := old.booking_reference;
      new.subtotal := old.subtotal;
      new.discount := old.discount;
      new.platform_fee := old.platform_fee;
      new.tax := old.tax;
      new.total := old.total;
      new.currency := old.currency;
      new.payment_status := old.payment_status;
      new.created_at := old.created_at;
      new.completed_at := old.completed_at;
    elsif tg_table_name='orders' then
      new.customer_id := old.customer_id;
      new.business_id := old.business_id;
      new.city_id := old.city_id;
      new.order_reference := old.order_reference;
      new.subtotal := old.subtotal;
      new.discount := old.discount;
      new.delivery_fee := old.delivery_fee;
      new.platform_fee := old.platform_fee;
      new.tax := old.tax;
      new.total := old.total;
      new.currency := old.currency;
      new.payment_status := old.payment_status;
      new.created_at := old.created_at;
      new.completed_at := old.completed_at;
    elsif tg_table_name='reviews' then
      new.author_user_id := old.author_user_id;
      new.target_user_id := old.target_user_id;
      new.listing_id := old.listing_id;
      new.business_id := old.business_id;
      new.booking_id := old.booking_id;
      new.order_id := old.order_id;
      new.verified_transaction := old.verified_transaction;
      new.created_at := old.created_at;
    end if;
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['users','businesses','listings','bookings','orders','reviews'] loop
    execute format('drop trigger if exists trg_%I_protected_fields on public.%I',t,t);
    execute format('create trigger trg_%I_protected_fields before update on public.%I for each row execute function public.prevent_protected_field_changes()',t,t);
  end loop;
end $$;

-- Explicitly keep these domains server/admin controlled: trust events, disputes,
-- evidence, fraud cases/signals, AI events/memory/knowledge, refunds writes,
-- commission writes. Absence of a policy is intentional.

commit;