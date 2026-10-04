-- CITYFLOW V1 — 003 transactional core
-- Apply only to the dedicated CITYFLOW database.
begin;

alter table public.listings add column if not exists inventory_quantity integer;
alter table public.listings add column if not exists inventory_reserved integer not null default 0;
alter table public.bookings add column if not exists idempotency_key text;
alter table public.orders add column if not exists idempotency_key text;

alter table public.listings drop constraint if exists listings_inventory_quantity_check;
alter table public.listings add constraint listings_inventory_quantity_check check (inventory_quantity is null or inventory_quantity >= 0);
alter table public.listings drop constraint if exists listings_inventory_reserved_check;
alter table public.listings add constraint listings_inventory_reserved_check check (inventory_reserved >= 0 and (inventory_quantity is null or inventory_reserved <= inventory_quantity));

create unique index if not exists bookings_customer_idempotency_key_uq on public.bookings(customer_id,idempotency_key) where idempotency_key is not null;
create unique index if not exists orders_customer_idempotency_key_uq on public.orders(customer_id,idempotency_key) where idempotency_key is not null;

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  status text not null default 'received',
  error_message text,
  unique(provider,provider_event_id)
);
create index if not exists payment_events_status_idx on public.payment_events(status,received_at desc);
alter table public.payment_events enable row level security;

create or replace function public.cityflow_booking_quote(
  p_customer_id uuid,p_listing_id uuid,p_start_at timestamptz,p_end_at timestamptz,
  p_quantity integer default 1,p_guests_count integer default null
) returns jsonb language plpgsql set search_path=public as $$
declare v_listing public.listings%rowtype; v_rule public.availability_rules%rowtype; v_subtotal numeric(14,2); v_total numeric(14,2);
begin
  if p_customer_id is null or p_listing_id is null or p_start_at is null or p_end_at is null or p_end_at<=p_start_at or p_quantity<=0 then
    raise exception using errcode='22023',message='invalid booking quote';
  end if;
  select * into v_listing from public.listings where id=p_listing_id and deleted_at is null;
  if not found then raise exception using errcode='P0002',message='listing not found'; end if;
  if v_listing.status<>'published' or v_listing.price is null then raise exception using errcode='P0001',message='listing is not bookable'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_listing_id::text,7319));
  if exists(select 1 from public.availability_blocks b where b.listing_id=p_listing_id and b.start_at<p_end_at and b.end_at>p_start_at) then
    raise exception using errcode='P0001',message='listing unavailable for selected dates';
  end if;
  if exists(select 1 from public.bookings b where b.listing_id=p_listing_id and b.status in ('pending','confirmed','in_progress') and b.start_at<p_end_at and coalesce(b.end_at,b.start_at+interval '1 minute')>p_start_at) then
    raise exception using errcode='P0001',message='listing already booked for selected dates';
  end if;
  select * into v_rule from public.availability_rules ar where ar.listing_id=p_listing_id and ar.start_date<=p_start_at::date and ar.end_date>=p_end_at::date and ar.status in ('available','available_until') order by ar.quantity desc limit 1;
  if found and v_rule.quantity<p_quantity then raise exception using errcode='P0001',message='requested quantity unavailable'; end if;
  v_subtotal:=round(v_listing.price*p_quantity,2); v_total:=v_subtotal;
  return jsonb_build_object('listing_id',v_listing.id,'currency',v_listing.currency,'subtotal',v_subtotal,'discount',0,'platform_fee',0,'tax',0,'total',v_total,'quantity',p_quantity,'guests_count',p_guests_count,'start_at',p_start_at,'end_at',p_end_at);
end; $$;
revoke all on function public.cityflow_booking_quote(uuid,uuid,timestamptz,timestamptz,integer,integer) from public,anon,authenticated;
grant execute on function public.cityflow_booking_quote(uuid,uuid,timestamptz,timestamptz,integer,integer) to service_role;

create or replace function public.cityflow_create_booking(
  p_customer_id uuid,p_listing_id uuid,p_start_at timestamptz,p_end_at timestamptz,
  p_quantity integer default 1,p_guests_count integer default null,p_special_requests jsonb default '{}'::jsonb,p_idempotency_key text default null
) returns jsonb language plpgsql set search_path=public as $$
declare q jsonb; l public.listings%rowtype; bid uuid; ref text;
begin
  if p_idempotency_key is not null then
    select jsonb_build_object('booking_id',id,'booking_reference',booking_reference,'status',status,'payment_status',payment_status,'total',total,'currency',currency) into q from public.bookings where customer_id=p_customer_id and idempotency_key=p_idempotency_key;
    if q is not null then return q; end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_listing_id::text,7319));
  q:=public.cityflow_booking_quote(p_customer_id,p_listing_id,p_start_at,p_end_at,p_quantity,p_guests_count);
  select * into l from public.listings where id=p_listing_id and deleted_at is null;
  ref:='CF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.bookings(customer_id,business_id,listing_id,city_id,booking_reference,start_at,end_at,quantity,guests_count,subtotal,discount,platform_fee,tax,total,currency,status,payment_status,special_requests,idempotency_key)
  values(p_customer_id,l.business_id,l.id,l.city_id,ref,p_start_at,p_end_at,p_quantity,p_guests_count,(q->>'subtotal')::numeric,(q->>'discount')::numeric,(q->>'platform_fee')::numeric,(q->>'tax')::numeric,(q->>'total')::numeric,l.currency,'pending','pending',coalesce(p_special_requests,'{}'::jsonb),p_idempotency_key) returning id into bid;
  insert into public.booking_items(booking_id,description,quantity,unit_price,subtotal) values(bid,l.title,p_quantity,l.price,(q->>'subtotal')::numeric);
  return jsonb_build_object('booking_id',bid,'booking_reference',ref,'status','pending','payment_status','pending','total',(q->>'total')::numeric,'currency',l.currency);
exception when unique_violation then
  select jsonb_build_object('booking_id',id,'booking_reference',booking_reference,'status',status,'payment_status',payment_status,'total',total,'currency',currency) into q from public.bookings where customer_id=p_customer_id and idempotency_key=p_idempotency_key;
  if q is not null then return q; end if; raise;
end; $$;
revoke all on function public.cityflow_create_booking(uuid,uuid,timestamptz,timestamptz,integer,integer,jsonb,text) from public,anon,authenticated;
grant execute on function public.cityflow_create_booking(uuid,uuid,timestamptz,timestamptz,integer,integer,jsonb,text) to service_role;

create or replace function public.cityflow_create_order(
  p_customer_id uuid,p_business_id uuid,p_city_id uuid,p_items jsonb,p_order_type text,
  p_delivery_address_id uuid default null,p_notes text default null,p_idempotency_key text default null
) returns jsonb language plpgsql set search_path=public as $$
declare oid uuid; ref text; total numeric(14,2):=0; item jsonb; l public.listings%rowtype; qty integer; line numeric(14,2); existing jsonb;
begin
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception using errcode='22023',message='items must be a non-empty array'; end if;
  if p_idempotency_key is not null then select jsonb_build_object('order_id',id,'order_reference',order_reference,'status',status,'payment_status',payment_status,'total',total,'currency',currency) into existing from public.orders where customer_id=p_customer_id and idempotency_key=p_idempotency_key; if existing is not null then return existing; end if; end if;
  for item in select value from jsonb_array_elements(p_items) loop
    qty:=greatest(1,(item->>'quantity')::integer);
    select * into l from public.listings where id=(item->>'listing_id')::uuid and business_id=p_business_id and deleted_at is null;
    if not found or l.status<>'published' or l.price is null then raise exception using errcode='P0002',message='order item not purchasable'; end if;
    perform pg_advisory_xact_lock(hashtextextended(l.id::text,9917));
    select * into l from public.listings where id=l.id for update;
    if l.inventory_quantity is not null and l.inventory_quantity-l.inventory_reserved<qty then raise exception using errcode='P0001',message='insufficient inventory'; end if;
    line:=round(l.price*qty,2); total:=total+line;
  end loop;
  ref:='CF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into public.orders(customer_id,business_id,city_id,order_reference,subtotal,total,currency,order_type,status,payment_status,delivery_address_id,notes,idempotency_key)
  values(p_customer_id,p_business_id,p_city_id,ref,total,total,'MAD',p_order_type,'pending','pending',p_delivery_address_id,p_notes,p_idempotency_key) returning id into oid;
  for item in select value from jsonb_array_elements(p_items) loop
    qty:=greatest(1,(item->>'quantity')::integer);
    select * into l from public.listings where id=(item->>'listing_id')::uuid for update;
    if l.inventory_quantity is not null then update public.listings set inventory_reserved=inventory_reserved+qty,updated_at=now() where id=l.id; end if;
    insert into public.order_items(order_id,listing_id,product_name,quantity,unit_price,subtotal,options) values(oid,l.id,l.title,qty,l.price,round(l.price*qty,2),coalesce(item->'options','{}'::jsonb));
  end loop;
  return jsonb_build_object('order_id',oid,'order_reference',ref,'status','pending','payment_status','pending','total',total,'currency','MAD');
exception when unique_violation then
  select jsonb_build_object('order_id',id,'order_reference',order_reference,'status',status,'payment_status',payment_status,'total',total,'currency',currency) into existing from public.orders where customer_id=p_customer_id and idempotency_key=p_idempotency_key;
  if existing is not null then return existing; end if; raise;
end; $$;
revoke all on function public.cityflow_create_order(uuid,uuid,uuid,jsonb,text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.cityflow_create_order(uuid,uuid,uuid,jsonb,text,uuid,text,text) to service_role;

create or replace function public.cityflow_create_verified_review(
  p_author_user_id uuid,p_rating numeric,p_content text,p_booking_id uuid default null,p_order_id uuid default null,p_target_user_id uuid default null,p_listing_id uuid default null,p_business_id uuid default null
) returns uuid language plpgsql set search_path=public as $$
declare rid uuid; valid_tx boolean:=false;
begin
  if p_booking_id is not null then select exists(select 1 from public.bookings where id=p_booking_id and customer_id=p_author_user_id and status='completed' and payment_status in ('captured','partially_refunded','refunded')) into valid_tx;
  elsif p_order_id is not null then select exists(select 1 from public.orders where id=p_order_id and customer_id=p_author_user_id and status='completed' and payment_status in ('captured','partially_refunded','refunded')) into valid_tx; end if;
  if not valid_tx then raise exception using errcode='42501',message='verified completed transaction required'; end if;
  insert into public.reviews(author_user_id,target_user_id,listing_id,business_id,booking_id,order_id,rating,content,status,verified_transaction) values(p_author_user_id,p_target_user_id,p_listing_id,p_business_id,p_booking_id,p_order_id,p_rating,p_content,'pending',true) returning id into rid;
  return rid;
end; $$;
revoke all on function public.cityflow_create_verified_review(uuid,numeric,text,uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.cityflow_create_verified_review(uuid,numeric,text,uuid,uuid,uuid,uuid,uuid) to service_role;

commit;