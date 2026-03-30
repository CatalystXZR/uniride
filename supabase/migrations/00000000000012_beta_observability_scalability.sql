-- Beta hardening: performance indexes + operational diagnostics.

-- 1) Performance indexes for hot paths.
create index if not exists idx_rides_active_departure_campus_direction
  on public.rides (departure_at, campus_id, direction)
  where status = 'active';

create index if not exists idx_bookings_reserved_by_ride
  on public.bookings (ride_id, created_at desc)
  where status = 'reserved';

create index if not exists idx_transactions_user_type_created
  on public.transactions (user_id, type, created_at desc);

create index if not exists idx_mp_payments_created_at
  on public.mp_payments (created_at desc);

-- 2) Daily operational metrics view.
create or replace view public.ops_daily_metrics as
with days as (
  select generate_series(
    (current_date - interval '29 days')::date,
    current_date::date,
    interval '1 day'
  )::date as day
),
rides_agg as (
  select date_trunc('day', created_at)::date as day, count(*) as rides_created
  from public.rides
  group by 1
),
bookings_agg as (
  select
    date_trunc('day', created_at)::date as day,
    count(*) as bookings_created,
    count(*) filter (where status = 'cancelled') as bookings_cancelled,
    count(*) filter (where status = 'completed') as bookings_completed,
    count(*) filter (where status = 'no_show') as bookings_no_show
  from public.bookings
  group by 1
),
topup_agg as (
  select
    date_trunc('day', created_at)::date as day,
    count(*) as topups_count,
    coalesce(sum(amount), 0) as topups_amount
  from public.transactions
  where type = 'topup'
  group by 1
),
strikes_agg as (
  select date_trunc('day', created_at)::date as day, count(*) as strikes_issued
  from public.strikes
  group by 1
)
select
  d.day,
  coalesce(r.rides_created, 0) as rides_created,
  coalesce(b.bookings_created, 0) as bookings_created,
  coalesce(b.bookings_cancelled, 0) as bookings_cancelled,
  coalesce(b.bookings_completed, 0) as bookings_completed,
  coalesce(b.bookings_no_show, 0) as bookings_no_show,
  coalesce(t.topups_count, 0) as topups_count,
  coalesce(t.topups_amount, 0) as topups_amount,
  coalesce(s.strikes_issued, 0) as strikes_issued
from days d
left join rides_agg r on r.day = d.day
left join bookings_agg b on b.day = d.day
left join topup_agg t on t.day = d.day
left join strikes_agg s on s.day = d.day
order by d.day desc;

-- 3) Wallet consistency diagnostic.
create or replace function public.wallet_reconciliation_diag(p_user_id uuid default null)
returns table (
  user_id uuid,
  wallet_available int,
  wallet_held int,
  expected_available int,
  expected_held int,
  available_delta int,
  held_delta int
)
language sql
security definer
set search_path = public
as $$
  with users_scope as (
    select w.user_id, w.balance_available, w.balance_held
    from public.wallets w
    where p_user_id is null or w.user_id = p_user_id
  ),
  tx_available as (
    select t.user_id, coalesce(sum(t.amount), 0)::int as expected_available
    from public.transactions t
    where p_user_id is null or t.user_id = p_user_id
    group by t.user_id
  ),
  booking_held as (
    select b.passenger_id as user_id, coalesce(sum(b.amount_total), 0)::int as expected_held
    from public.bookings b
    where b.status = 'reserved'
      and (p_user_id is null or b.passenger_id = p_user_id)
    group by b.passenger_id
  )
  select
    u.user_id,
    u.balance_available as wallet_available,
    u.balance_held as wallet_held,
    coalesce(a.expected_available, 0) as expected_available,
    coalesce(h.expected_held, 0) as expected_held,
    u.balance_available - coalesce(a.expected_available, 0) as available_delta,
    u.balance_held - coalesce(h.expected_held, 0) as held_delta
  from users_scope u
  left join tx_available a on a.user_id = u.user_id
  left join booking_held h on h.user_id = u.user_id
  order by u.user_id;
$$;

grant execute on function public.wallet_reconciliation_diag(uuid) to authenticated;
