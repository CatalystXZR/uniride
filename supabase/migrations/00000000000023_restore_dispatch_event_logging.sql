-- Migration 23: Restore dispatch event logging + no-show hardening
-- Migration 18 dropped event logging from several functions and broke passenger_report_no_show.
-- This migration restores those features while keeping Chile timezone handling.

begin;

-- =============
-- 1) driver_cancel_ride: restore dispatch_status on bookings, event log, strike counter, wallet guard
-- =============
create or replace function public.driver_cancel_ride(
  p_ride_id uuid,
  p_reason text default 'cancelled_by_driver'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_booking record;
  v_departure timestamp;
  v_now timestamp := public.current_chile_time();
begin
  if v_driver is null then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from rides where id = p_ride_id and driver_id = v_driver and status = 'active'
  ) then
    raise exception 'forbidden' using errcode = 'P0006';
  end if;

  update rides
  set status = 'cancelled',
      cancel_reason = coalesce(nullif(trim(p_reason), ''), 'cancelled_by_driver'),
      cancelled_at = now(),
      seats_available = seats_total
  where id = p_ride_id
  returning departure_at into v_departure;

  for v_booking in
    select id, passenger_id, amount_total, dispatch_status
    from bookings
    where ride_id = p_ride_id and status = 'reserved'
    for update
  loop
    update wallets
    set balance_held = balance_held - v_booking.amount_total,
        balance_available = balance_available + v_booking.amount_total,
        updated_at = now()
    where user_id = v_booking.passenger_id
      and balance_held >= v_booking.amount_total;

    if not found then
      raise exception 'held_balance_mismatch' using errcode = 'P0012';
    end if;

    update bookings
    set status = 'cancelled',
        dispatch_status = 'cancelled',
        cancelled_at = now(),
        cancelled_by = v_driver,
        cancel_reason = coalesce(nullif(trim(p_reason), ''), 'cancelled_by_driver')
    where id = v_booking.id;

    insert into transactions (user_id, booking_id, type, amount, metadata)
    values (
      v_booking.passenger_id,
      v_booking.id,
      'refund',
      v_booking.amount_total,
      jsonb_build_object('ride_id', p_ride_id, 'reason', 'driver_cancelled')
    );

    perform public.log_booking_event(
      v_booking.id,
      p_ride_id,
      v_driver,
      'driver',
      v_booking.dispatch_status,
      'cancelled'::booking_dispatch_status,
      'driver_cancelled_ride',
      jsonb_build_object('reason', coalesce(nullif(trim(p_reason), ''), 'cancelled_by_driver'))
    );
  end loop;

  if v_now >= v_departure - interval '2 hours' then
    insert into strikes (driver_id, reason, source, expires_at)
    values (v_driver, 'driver_cancelled_ride', 'driver_cancel', now() + interval '2 months');

    update users_profile
    set strikes_count = strikes_count + 1,
        suspended_until = case
          when strikes_count + 1 >= 2
            then greatest(coalesce(suspended_until, now()), now() + interval '2 months')
          else suspended_until
        end,
        vehicle_suspended_until = case
          when strikes_count + 1 >= 2
            then greatest(coalesce(vehicle_suspended_until, now()), now() + interval '2 months')
          else vehicle_suspended_until
        end
    where id = v_driver;
  end if;
end $$;

-- =============
-- 2) driver_accept_booking: restore event log
-- =============
create or replace function public.driver_accept_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver uuid := auth.uid();
  v_owner uuid;
  v_ride_id uuid;
  v_status booking_status;
  v_dispatch booking_dispatch_status;
  v_departure timestamp;
  v_now timestamp := public.current_chile_time();
begin
  if v_driver is null then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  select r.driver_id, b.ride_id, b.status, b.dispatch_status, r.departure_at
    into v_owner, v_ride_id, v_status, v_dispatch, v_departure
  from bookings b
  join rides r on r.id = b.ride_id
  where b.id = p_booking_id
  for update of b;

  if not found then
    raise exception 'booking not found or already processed' using errcode = 'P0005';
  end if;

  if v_owner is distinct from v_driver then
    raise exception 'forbidden' using errcode = 'P0006';
  end if;

  if v_status <> 'reserved' then
    raise exception 'booking_not_active' using errcode = 'P0011';
  end if;

  if v_dispatch <> 'reserved' then
    raise exception 'invalid_dispatch_transition' using errcode = 'P0011';
  end if;

  if v_departure <= v_now then
    raise exception 'ride_departed' using errcode = 'P0010';
  end if;

  update bookings
  set dispatch_status = 'accepted',
      driver_accepted_at = coalesce(driver_accepted_at, now())
  where id = p_booking_id;

  perform public.log_booking_event(
    p_booking_id,
    v_ride_id,
    v_driver,
    'driver',
    v_dispatch,
    'accepted'::booking_dispatch_status,
    'driver_accepted_booking'
  );
end $$;

-- =============
-- 2) cancel_booking: restore event log + ride completion check
-- =============
create or replace function public.cancel_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_passenger uuid := auth.uid();
  v_booking_passenger uuid;
  v_ride_id uuid;
  v_amount int;
  v_departure timestamp;
  v_dispatch booking_dispatch_status;
  v_now timestamp := public.current_chile_time();
begin
  if v_passenger is null then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  select b.passenger_id, b.ride_id, b.amount_total, r.departure_at, b.dispatch_status
    into v_booking_passenger, v_ride_id, v_amount, v_departure, v_dispatch
  from bookings b
  join rides r on r.id = b.ride_id
  where b.id = p_booking_id
    and b.status = 'reserved'
  for update of b;

  if not found then
    raise exception 'booking not found or already processed' using errcode = 'P0005';
  end if;

  if v_booking_passenger is distinct from v_passenger then
    raise exception 'forbidden' using errcode = 'P0006';
  end if;

  if v_dispatch in ('passenger_boarded', 'in_progress') then
    raise exception 'cannot_cancel_started_trip' using errcode = 'P0011';
  end if;

  if v_now > v_departure + interval '10 minutes' then
    raise exception 'cancel_window_expired' using errcode = 'P0013';
  end if;

  update wallets
  set balance_held = balance_held - v_amount,
      balance_available = balance_available + v_amount,
      updated_at = now()
  where user_id = v_passenger
    and balance_held >= v_amount;

  if not found then
    raise exception 'held_balance_mismatch' using errcode = 'P0012';
  end if;

  update rides
  set seats_available = least(seats_total, seats_available + 1)
  where id = v_ride_id
    and status = 'active';

  update bookings
  set status = 'cancelled',
      dispatch_status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = v_passenger,
      cancel_reason = 'cancelled_by_passenger'
  where id = p_booking_id;

  insert into transactions (user_id, booking_id, type, amount, metadata)
  values (
    v_passenger,
    p_booking_id,
    'refund',
    v_amount,
    jsonb_build_object('ride_id', v_ride_id, 'reason', 'passenger_cancelled')
  );

  perform public.log_booking_event(
    p_booking_id,
    v_ride_id,
    v_passenger,
    'passenger',
    v_dispatch,
    'cancelled'::booking_dispatch_status,
    'passenger_cancelled_booking'
  );

  perform public.set_ride_completed_if_no_open_bookings(v_ride_id);
end $$;

-- =============
-- 3) passenger_report_no_show: full restore with Chile timezone
-- =============
create or replace function public.passenger_report_no_show(
  p_booking_id uuid,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_passenger uuid := auth.uid();
  v_driver uuid;
  v_ride_id uuid;
  v_amount int;
  v_departure timestamp;
  v_dispatch booking_dispatch_status;
  v_now timestamp := public.current_chile_time();
begin
  if v_passenger is null then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  select b.passenger_id,
         b.ride_id,
         b.amount_total,
         b.dispatch_status,
         r.driver_id,
         r.departure_at
    into v_passenger,
         v_ride_id,
         v_amount,
         v_dispatch,
         v_driver,
         v_departure
  from bookings b
  join rides r on r.id = b.ride_id
  where b.id = p_booking_id
    and b.status = 'reserved'
    and b.passenger_id = auth.uid()
  for update of b;

  if not found then
    raise exception 'booking not found or already processed' using errcode = 'P0005';
  end if;

  if v_dispatch not in ('accepted', 'driver_arriving', 'driver_arrived') then
    raise exception 'invalid_dispatch_transition' using errcode = 'P0011';
  end if;

  if v_now < v_departure + interval '10 minutes' then
    raise exception 'wait_time_not_elapsed' using errcode = 'P0008';
  end if;

  if v_now > v_departure + interval '12 hours' then
    raise exception 'report_window_expired' using errcode = 'P0013';
  end if;

  update wallets
  set balance_held = balance_held - v_amount,
      balance_available = balance_available + v_amount,
      updated_at = now()
  where user_id = v_passenger
    and balance_held >= v_amount;

  if not found then
    raise exception 'held_balance_mismatch' using errcode = 'P0012';
  end if;

  update rides
  set seats_available = least(seats_total, seats_available + 1)
  where id = v_ride_id
    and status = 'active';

  update bookings
  set status = 'no_show',
      dispatch_status = 'no_show',
      reported_no_show_at = now(),
      no_show_notes = p_notes,
      cancelled_at = now(),
      cancelled_by = v_passenger,
      cancel_reason = 'driver_no_show'
  where id = p_booking_id;

  insert into transactions (user_id, booking_id, type, amount, metadata)
  values (
    v_passenger,
    p_booking_id,
    'refund',
    v_amount,
    jsonb_build_object('ride_id', v_ride_id, 'reason', 'driver_no_show')
  );

  insert into strikes (driver_id, reason, booking_id, source, expires_at)
  values (v_driver, 'driver_no_show', p_booking_id, 'passenger_report', now() + interval '2 months');

  update users_profile
  set strikes_count = strikes_count + 1,
      suspended_until = case
        when strikes_count + 1 >= 2
          then greatest(coalesce(suspended_until, now()), now() + interval '2 months')
        else suspended_until
      end,
      vehicle_suspended_until = case
        when strikes_count + 1 >= 2
          then greatest(coalesce(vehicle_suspended_until, now()), now() + interval '2 months')
        else vehicle_suspended_until
      end
  where id = v_driver;

  perform public.log_booking_event(
    p_booking_id,
    v_ride_id,
    v_passenger,
    'passenger',
    v_dispatch,
    'no_show'::booking_dispatch_status,
    'passenger_reported_no_show',
    jsonb_build_object('notes', coalesce(p_notes, ''))
  );

  perform public.set_ride_completed_if_no_open_bookings(v_ride_id);
end $$;

commit;
