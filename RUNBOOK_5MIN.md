# RUNBOOK 5 MIN - TurnoApp

Comandos copy-paste para operar rapido.

Proyecto Supabase:
- `zawaevytpkvejhekyokw`

---

## 1) Levantar app local (Edge)

```powershell
Set-Location "C:\Users\matia\Desktop\UniRide\uniride-main\turnoapp"
flutter pub get
flutter run -d edge
```

---

## 2) Aplicar migraciones DB

```powershell
Set-Location "C:\Users\matia\Desktop\UniRide\uniride-main"
supabase login
supabase link --project-ref zawaevytpkvejhekyokw
supabase db push
```

---

## 3) Desplegar Edge Functions

```powershell
Set-Location "C:\Users\matia\Desktop\UniRide\uniride-main"
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

Secrets obligatorios en Supabase Dashboard -> Settings -> Edge Functions:
- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`

---

## 4) Build web release

```powershell
Set-Location "C:\Users\matia\Desktop\UniRide\uniride-main\turnoapp"
flutter analyze
flutter build web --release
```

---

## 5) Deploy rapido Vercel (si aplica)

```powershell
Set-Location "C:\Users\matia\Desktop\UniRide\uniride-main\turnoapp\build\web"
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
```

---

## 7) Si algo falla (atajo)

- Error `supabase not found`:
  - instala/actualiza CLI y reabre PowerShell.
- Error `No pubspec.yaml file found`:
  - entra a `...\turnoapp` antes de correr `flutter`.
- Universidades no cargan:
  - correr `supabase db push` y revisar migraciones 06-09.

---

## 8) Docs completas

- `START_HERE_IA.md` (handoff tecnico largo)
- `CHECKLIST_RELEASE.md` (checklist release)
