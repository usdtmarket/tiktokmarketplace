-- CITYFLOW V1 — 006 payment state machine
-- Provider-neutral core. CMI-specific signing/fields must be added from the merchant integration kit.
begin;

create unique index if not exists payments_provider_transaction_uq
on public.payments(provider,provider_transaction_id)
where provider_transaction_id is not null;

create unique index if not exists payments_booking_pending_uq
on public.payments(booking_id)
where booking_id is not null and status in ('pending','authorized','captured');

create unique index if not exists payments_order_pending_uq
on public.payments(order_id)
where order_id is not null and status in ('pending','authorized','captured');

create index if not exists refunds_payment_id_idx on public.refunds(payment_id);
create index if not exists commissions_booking_id_idx on public.commissions(booking_id);
create index if not exists commissions_order_id_idx on public.commissions(order_id);

create or replace function public.cityflow_apply_payment_event(
  p_provider text,
  p_provider_event_id text,
  p_event_type text,
  p_payload jsonb,
  p_provider_transaction_id text,
  p_payment_id uuid default null,
  p_status payment_status default null
) returns jsonb
language plpgsql
set search_path=public
as $$
declare
  ev public.payment_events%rowtype;
  pay public.payments%rowtype;
  b public.bookings%rowtype;
  o public.orders%rowtype;
  v_status payment_status;
begin
  if nullif(trim(p_provider),'') is null
     or nullif(trim(p_provider_event_id),'') is null
     or nullif(trim(p_event_type),'') is null then
    raise exception using errcode='22023',message='payment event identity required';
  end if;

  insert into public.payment_events(provider,provider_event_id,event_type,payload,status)
  values(p_provider,p_provider_event_id,p_event_type,coalesce(p_payload,'{}'::jsonb),'received')
  on conflict(provider,provider_event_id) do nothing
  returning * into ev;

  if ev.id is null then
    select * into ev from public.payment_events
    where provider=p_provider and provider_event_id=p_provider_event_id;
    return jsonb_build_object('duplicate',true,'event_id',ev.id,'status',ev.status);
  end if;

  if p_payment_id is null then
    select * into pay from public.payments
    where provider=p_provider and provider_transaction_id=p_provider_transaction_id
    for update;
  else
    select * into pay from public.payments where id=p_payment_id for update;
  end if;

  if not found then
    update public.payment_events set status='failed',error_message='payment record not found',processed_at=now() where id=ev.id;
    raise exception using errcode='P0002',message='payment record not found';
  end if;

  v_status:=coalesce(p_status,
    case
      when lower(p_event_type) like '%capture%' or lower(p_event_type) like '%success%' or lower(p_event_type) like '%paid%' then 'captured'::payment_status
      when lower(p_event_type) like '%author%' then 'authorized'::payment_status
      when lower(p_event_type) like '%fail%' or lower(p_event_type) like '%declin%' then 'failed'::payment_status
      when lower(p_event_type) like '%cancel%' then 'cancelled'::payment_status
      when lower(p_event_type) like '%refund%' then 'refunded'::payment_status
      else null
    end);

  if v_status is null then
    update public.payment_events set status='failed',error_message='unsupported payment event',processed_at=now() where id=ev.id;
    raise exception using errcode='22023',message='unsupported payment event';
  end if;

  if v_status='captured' and pay.status not in ('pending','authorized','captured') then
    update public.payment_events set status='failed',error_message='invalid capture transition',processed_at=now() where id=ev.id;
    raise exception using errcode='P0001',message='invalid payment transition';
  end if;

  if v_status='refunded' and pay.status not in ('captured','partially_refunded','refunded') then
    update public.payment_events set status='failed',error_message='invalid refund transition',processed_at=now() where id=ev.id;
    raise exception using errcode='P0001',message='invalid refund transition';
  end if;

  update public.payments
  set status=v_status,
      provider_transaction_id=coalesce(p_provider_transaction_id,provider_transaction_id),
      authorized_at=case when v_status='authorized' then coalesce(authorized_at,now()) else authorized_at end,
      captured_at=case when v_status='captured' then coalesce(captured_at,now()) else captured_at end,
      failed_at=case when v_status='failed' then coalesce(failed_at,now()) else failed_at end,
      refunded_at=case when v_status='refunded' then coalesce(refunded_at,now()) else refunded_at end,
      updated_at=now()
  where id=pay.id
  returning * into pay;

  if pay.booking_id is not null then
    select * into b from public.bookings where id=pay.booking_id for update;
    if v_status='captured' then
      update public.bookings set payment_status='captured',status=case when status='pending' then 'confirmed' else status end,updated_at=now() where id=b.id;
    elsif v_status='failed' then update public.bookings set payment_status='failed',updated_at=now() where id=b.id;
    elsif v_status='cancelled' then update public.bookings set payment_status='cancelled',updated_at=now() where id=b.id;
    elsif v_status='refunded' then update public.bookings set payment_status='refunded',status=case when status<>'cancelled' then 'refunded' else status end,updated_at=now() where id=b.id;
    end if;
  end if;

  if pay.order_id is not null then
    select * into o from public.orders where id=pay.order_id for update;
    if v_status='captured' then
      update public.orders set payment_status='captured',status=case when status='pending' then 'confirmed' else status end,updated_at=now() where id=o.id;
    elsif v_status='failed' then update public.orders set payment_status='failed',updated_at=now() where id=o.id;
    elsif v_status='cancelled' then update public.orders set payment_status='cancelled',updated_at=now() where id=o.id;
    elsif v_status='refunded' then update public.orders set payment_status='refunded',status=case when status<>'cancelled' then 'refunded' else status end,updated_at=now() where id=o.id;
    end if;
  end if;

  update public.payment_events set status='processed',processed_at=now() where id=ev.id;
  return jsonb_build_object('duplicate',false,'event_id',ev.id,'payment_id',pay.id,'payment_status',pay.status,'booking_id',pay.booking_id,'order_id',pay.order_id);
exception when others then
  update public.payment_events set status='failed',error_message=left(sqlerrm,500),processed_at=now() where id=ev.id;
  raise;
end;
$$;

revoke all on function public.cityflow_apply_payment_event(text,text,text,jsonb,text,uuid,payment_status) from public,anon,authenticated;
grant execute on function public.cityflow_apply_payment_event(text,text,text,jsonb,text,uuid,payment_status) to service_role;

create or replace function public.cityflow_create_payment_record(
  p_user_id uuid,p_booking_id uuid default null,p_order_id uuid default null
) returns jsonb
language plpgsql
set search_path=public
as $$
declare
  v_amount numeric; v_currency char(3); v_payment public.payments%rowtype;
begin
  if (p_booking_id is null and p_order_id is null) or (p_booking_id is not null and p_order_id is not null) then
    raise exception using errcode='22023',message='exactly one transaction reference is required';
  end if;
  if p_booking_id is not null then
    select total,currency into v_amount,v_currency from public.bookings where id=p_booking_id and customer_id=p_user_id and status='pending' and payment_status='pending';
  else
    select total,currency into v_amount,v_currency from public.orders where id=p_order_id and customer_id=p_user_id and status='pending' and payment_status='pending';
  end if;
  if v_amount is null then raise exception using errcode='P0001',message='transaction is not payable'; end if;
  insert into public.payments(user_id,booking_id,order_id,provider,amount,currency,status)
  values(p_user_id,p_booking_id,p_order_id,'cmi',v_amount,v_currency,'pending')
  on conflict do nothing returning * into v_payment;
  if v_payment.id is null then
    select * into v_payment from public.payments where (p_booking_id is not null and booking_id=p_booking_id) or (p_order_id is not null and order_id=p_order_id) order by created_at desc limit 1;
  end if;
  return jsonb_build_object('payment_id',v_payment.id,'amount',v_payment.amount,'currency',v_payment.currency,'status',v_payment.status,'provider',v_payment.provider);
end;
$$;

revoke all on function public.cityflow_create_payment_record(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.cityflow_create_payment_record(uuid,uuid,uuid) to service_role;

commit;