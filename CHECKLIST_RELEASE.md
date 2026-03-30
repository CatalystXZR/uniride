# CHECKLIST RELEASE - TurnoApp (Linux/Fedora)

Checklist corta para sacar release sin romper produccion.

---

## 0) Preflight

- Estar en `main` limpio (o branch de release).
- Tener Flutter y Supabase CLI instalados.
- Confirmar proyecto Supabase correcto: `zawaevytpkvejhekyokw`.
- Leer `START_HERE_IA.md` y `PLAN_BETA_ESCALABLE.md` si hubo cambios grandes.

---

## 1) Base de datos

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase login
supabase link --project-ref zawaevytpkvejhekyokw
supabase db push
```

Resultado esperado: sin errores y sin migraciones pendientes.

---

## 2) Edge Functions y secretos

En Supabase Dashboard -> Settings -> Edge Functions -> Secrets, validar:

- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`

Luego desplegar funciones:

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

---

## 3) Build Flutter Web

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp"
flutter pub get
flutter analyze
if [ -d test ]; then flutter test; fi
flutter build web --release \
  --dart-define=SUPABASE_URL=https://zawaevytpkvejhekyokw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Notas:
- `analyze` puede mostrar infos no bloqueantes; si hay `error`, no liberar.
- Para multi-entorno, preferir `--dart-define` en build/release.

---

## 4) Deploy frontend

Si usas Vercel estatico:

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp/build/web"
vercel --prod
```

Confirmar rewrite SPA (`/index.html`) activo para rutas internas.

---

## 5) Smoke test post-release (minimo)

1. Registro nuevo usuario
   - Debe exigir terminos.
2. Home
   - Modo conductor bloquea sin licencia.
3. Publicar turno
   - Debe pedir punto de encuentro.
   - Precio 2500 para PUC/UCH, 2000 para resto.
4. Reserva
   - Retiene saldo correctamente.
5. Confirmar abordaje
   - Libera pago y registra fee/neto.
6. Mis reservas
   - Reporte no-show antes de 10 min debe bloquear.
7. Mis turnos conductor
   - Cancelar ride reembolsa pasajeros.
8. Wallet
   - Crear topup intent + webhook acredita.

---

## 6) Verificaciones SQL rapidas

En Supabase SQL Editor:

```sql
select count(*) from universities;
select count(*) from campuses;
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

## 7) Rollback rapido

- Frontend: redeployar build anterior en Vercel.
- Backend: si fallo por migracion, crear migracion correctiva nueva (no borrar historial).
- Edge Functions: redeployar version previa.

---

## 8) Criterio de release OK

- `supabase db push` sin error.
- Edge Functions desplegadas y con secrets.
- `flutter build web --release` exitoso.
- Smoke test minimo 100% OK.
- Sin errores criticos en logs de Supabase Functions.
