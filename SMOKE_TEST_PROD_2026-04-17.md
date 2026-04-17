# Smoke Test Prod - 2026-04-17

Registro de validacion post-release en produccion.

## 1) Contexto

- Branch: `main`
- Commit docs sync: `ea8cd20`
- Objetivo: validar estado tecnico actual y dejar checklist manual fin-a-fin listo para ejecucion.

## 2) Verificaciones automaticas ejecutadas

### 2.1 Repo

- `git status --short --branch` -> limpio (`main...origin/main`).

### 2.2 Flutter

- `flutter analyze` -> sin errores bloqueantes, 88 issues de tipo `info`.
- `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` -> OK, build generado en `turnoapp/build/web`.
- `flutter test` -> no ejecutado porque no existe carpeta `test/` (`NO_TEST_DIR`).

### 2.3 Supabase (via CLI)

Nota: la CLI global no estaba instalada en el PATH (`supabase: command not found`), se uso `npx supabase`.

- `npx supabase --version` -> `2.92.1`.
- `npx supabase migration list --linked` -> local y remoto sincronizados desde `00000000000000` hasta `00000000000015`.
- `npx supabase functions list --project-ref zawaevytpkvejhekyokw` -> funciones activas:
  - `create-topup-intent` (v4)
  - `mercadopago-webhook` (v4)
  - `create-stripe-topup-session` (v3)
  - `stripe-webhook` (v3)
  - `delete-account` (v3)
- `npx supabase secrets list --project-ref zawaevytpkvejhekyokw` -> secretos presentes (nombres):
  - `PAYMENT_PROVIDER`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_DB_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_URL`

## 3) Resultado tecnico actual

- Estado automatizado: OK para continuar con validacion manual E2E.
- Riesgo controlado: pagos pueden mantenerse en modo seguro con `PAYMENT_PROVIDER=disabled` hasta conectar credenciales reales de proveedor.

## 4) Checklist manual fin-a-fin (pendiente)

Ejecutar en entorno productivo con cuentas reales de prueba:

- [ ] Registro/login
- [ ] Publicar turno (pricing esperado)
- [ ] Buscar/reservar
- [ ] Flujo despacho: aceptar -> en camino -> llego -> abordar -> iniciar -> finalizar
- [ ] Cancelaciones pasajero/conductor
- [ ] No-show dentro/fuera de ventana valida
- [ ] Wallet topup en modo actual (disabled) y mensaje UX correcto
- [ ] Solicitud retiro
- [ ] Eliminar cuenta desde perfil

## 5) Rollback (referencias vigentes)

- Branch backup: `backup/main-before-dispatch-origin-be3ca77`
- Tag estable: `stable-pre-dispatch-be3ca77`
