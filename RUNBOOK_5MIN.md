# RUNBOOK 5 MIN - TurnoApp (Linux/Fedora)

Comandos copy-paste para operar rapido en Linux.

Proyecto Supabase:
- `zawaevytpkvejhekyokw`

---

## 1) Levantar app local (Chrome)

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp"
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://zawaevytpkvejhekyokw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

---

## 2) Aplicar migraciones DB

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase login
supabase link --project-ref zawaevytpkvejhekyokw
supabase db push
```

---

## 3) Desplegar Edge Functions

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
supabase functions deploy create-stripe-topup-session
supabase functions deploy stripe-webhook
supabase functions deploy delete-account
```

Secrets obligatorios en Supabase Dashboard -> Settings -> Edge Functions:
- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`
- `PAYMENT_PROVIDER` (`disabled`, `mercadopago` o `stripe`)

Stripe-ready (cuando se conecte):
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_WEBHOOK_SECRET`

---

## 4) Build web release

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp"
flutter analyze
flutter build web --release \
  --dart-define=SUPABASE_URL=https://zawaevytpkvejhekyokw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

---

## 5) Deploy rapido Vercel (si aplica)

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp/build/web"
vercel --prod
```

---

## 6) SQL quick health-check

Ejecutar en Supabase SQL Editor:

```sql
select count(*) as universities_count from universities;
select count(*) as campuses_count from campuses;
select * from reference_access_diag();

select id, seat_price, platform_fee, driver_net_amount, is_radial
from rides
order by created_at desc
limit 10;

select id, strikes_count, suspended_until, vehicle_suspended_until
from users_profile
order by created_at desc
limit 10;

select * from ops_daily_metrics limit 7;
select * from wallet_reconciliation_diag(null) limit 20;

select dispatch_status, count(*)
from bookings
group by dispatch_status
order by dispatch_status;

select proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname='public'
  and proname in (
    'driver_accept_booking','driver_mark_arriving','driver_mark_arrived',
    'driver_start_trip','driver_complete_trip','driver_reject_booking',
    'expire_past_active_rides'
  )
order by proname;
```

---

## 7) Si algo falla (atajo)

- Error `supabase: command not found`:
  - instala/actualiza Supabase CLI y reinicia terminal.
- Error `No pubspec.yaml file found`:
  - entra a `.../turnoapp` antes de correr `flutter`.
- Universidades no cargan:
  - correr `supabase db push` y revisar migraciones 06-12.

---

## 8) Docs completas

- `START_HERE_IA.md` (handoff tecnico largo)
- `CHECKLIST_RELEASE.md` (checklist release)
- `PLAN_BETA_ESCALABLE.md` (roadmap beta)
