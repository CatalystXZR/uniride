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
```

Secrets obligatorios en Supabase Dashboard -> Settings -> Edge Functions:
- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`

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
