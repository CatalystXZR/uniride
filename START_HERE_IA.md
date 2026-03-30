# START HERE IA - TurnoApp Handoff Tecnico Completo

> Documento maestro para que cualquier IA (o dev nuevo) pueda retomar el proyecto,
> entender estado real, completar pendientes y desplegar sin romper el MVP.

---

## 1) Que es TurnoApp

TurnoApp es una PWA de carpooling universitario en Chile (Flutter Web + Supabase).

- Usuarios: estudiantes (pasajeros) y estudiantes conductores.
- Flujo principal: publicar turno -> reservar -> retencion de fondos -> liberar pago al conductor con confirmacion.
- Pagos: Mercado Pago Checkout Pro + webhook idempotente.
- Enfoque actual: MVP funcional con capa de seguridad/legales/strikes agregada.

---

## 2) Estado actual (Mar 2026)

### Implementado y funcional

- Auth email/password con Supabase.
- Registro con aceptacion de terminos y declaracion de licencia vigente.
- Cambio de modo pasajero/conductor con gate de seguridad.
- Publicacion de turnos con:
  - punto de encuentro,
  - radial opcional,
  - precio y comision calculados.
- Busqueda y reserva de turnos.
- Confirmacion de abordaje (libera pago conductor).
- Cancelacion de reserva (refund).
- Reporte no-show (pasajero reporta conductor ausente tras espera minima).
- Cancelacion de turno por conductor con reembolso a pasajeros.
- Sistema de strikes y suspension por 2 meses (conductor + auto) al acumular 2.
- Wallet y recarga Mercado Pago por Edge Functions.

### Aun pendiente (no implementado o parcial)

- Integracion Fintoc (solo MP hoy).
- Chat en vivo.
- Favoritos (perfiles/turnos).
- Tema oscuro negro completo.
- Sistema completo de rating/reviews post-viaje (hay campos, no flujo completo).
- Verificacion documental real de licencia (KYC/upload/admin review).
- Perfil editable completo (foto, auto, patente, etc. hoy solo lectura parcial en reservas).

---

## 3) Stack, lenguajes y herramientas

- Frontend: Flutter Web (Dart)
- Backend: Supabase (Postgres + RLS + RPC + Auth)
- Serverless: Edge Functions (Deno + TypeScript)
- Pagos: Mercado Pago

Dependencias clave (`turnoapp/pubspec.yaml`):
- `supabase_flutter`
- `go_router`
- `flutter_riverpod`
- `intl`
- `google_fonts`
- `url_launcher`

---

## 4) Ubicacion del codigo

Raiz del repo:

```text
uniride/
├─ turnoapp/                # Flutter app
│  └─ lib/
│     ├─ app/               # app.dart, router.dart, theme.dart
│     ├─ core/              # constants.dart, supabase_client.dart, error_mapper.dart
│     ├─ models/            # ride, booking, user_profile, etc.
│     ├─ services/          # auth/profile/ride/booking/wallet/legal
│     └─ features/          # pantallas por modulo
└─ supabase/
   ├─ migrations/           # 00..12
   └─ functions/            # create-topup-intent, mercadopago-webhook
```

Archivo clave para empezar:
- `turnoapp/lib/core/supabase_client.dart`
- `supabase/migrations/00000000000009_compliance_pricing_strikes.sql`

---

## 5) Arquitectura (alto nivel)

```text
Flutter Web (PWA)
  -> Services (Dart)
    -> Supabase Auth / PostgREST / RPC
      -> Postgres + RLS
      -> Edge Functions (MP)
         -> Mercado Pago API
```

### Flujo financiero principal

```text
Reserva:
  create_booking RPC
  - valida disponibilidad
  - retiene saldo pasajero (available -> held)
  - crea booking + tx booking_hold

Confirmar abordaje:
  confirm_boarding RPC
  - libera held pasajero
  - acredita neto al conductor
  - registra platform_fee en transactions

Cancelacion:
  cancel_booking RPC
  - refund pasajero
```

### Flujo de strikes/suspension

```text
Conductor cancela ride tarde / pasajero reporta no-show
  -> inserta strike
  -> users_profile.strikes_count += 1
  -> si strikes_count >= 2:
       suspended_until +2 meses
       vehicle_suspended_until +2 meses
```

---

## 6) Base de datos - migraciones y estado

Migraciones actuales:

1. `00000000000000_schema.sql`
2. `00000000000001_rls.sql`
3. `00000000000002_functions.sql`
4. `00000000000003_auth_trigger.sql`
5. `00000000000004_seed.sql`
6. `00000000000005_webhook_rpc.sql`
7. `00000000000006_public_grants.sql`
8. `00000000000007_reference_rls.sql`
9. `00000000000008_reference_diag.sql`
10. `00000000000009_compliance_pricing_strikes.sql`
11. `00000000000010_profile_photos_storage.sql`
12. `00000000000011_driver_vehicle_required.sql`
13. `00000000000012_beta_observability_scalability.sql`

### Cambios importantes en 12

- Índices parciales para rides activas y bookings reservadas.
- Índice compuesto de transacciones por usuario/tipo/fecha.
- Vista operativa `ops_daily_metrics` (ultimos 30 dias).
- Función `wallet_reconciliation_diag(uuid)` para conciliación wallet/ledger.

### Cambios importantes en 09

- Nuevas columnas en `users_profile`:
  - `accepted_terms`, `accepted_terms_at`, `terms_version`
  - `has_valid_license`, `license_checked_at`
  - `emergency_contact`, `safety_notes`, `profile_photo_url`
  - `rating_avg`, `rating_count`
  - `vehicle_model`, `vehicle_plate`, `vehicle_color`, `vehicle_suspended_until`
- Nuevas columnas en `rides`:
  - `meeting_point`, `is_radial`, `platform_fee`, `driver_net_amount`
  - `cancel_reason`, `cancelled_at`
- Nuevas columnas en `bookings`:
  - `reported_no_show_at`, `no_show_notes`
- Trigger `trg_enforce_ride_pricing` para forzar pricing por universidad/radial.
- RPC nuevas:
  - `driver_cancel_ride(p_ride_id, p_reason)`
  - `passenger_report_no_show(p_booking_id, p_notes)`
- `confirm_boarding` actualizado para neto + fee.
- Politicas adicionales de lectura de perfiles y restriccion de insert ride a conductor habilitado.

---

## 7) Reglas de negocio vigentes

- Precio asiento:
  - `2000` para UDD/UANDES/UAI/UNAB
  - `2500` para PUC/UCH
- Comision plataforma:
  - 14.25% normal
  - 15.25% radial
- Espera para no-show: 10 minutos.
- 2 strikes -> suspension 2 meses conductor + auto.
- Modo conductor requiere:
  - terminos aceptados
  - licencia vigente declarada
  - no estar suspendido

---

## 8) Seguridad y legales

- RLS habilitado en tablas sensibles.
- Operaciones monetarias por RPC `SECURITY DEFINER`.
- Webhook MP con verificacion HMAC (`MP_WEBHOOK_SECRET`).
- Pantalla de terminos: `turnoapp/lib/features/legal/terms_screen.dart`.
- Boton de panico (UI): aviso para llamar al `133`.

---

## 9) Configuracion de entorno

## Flutter

El proyecto actualmente tiene defaults en `supabase_client.dart` apuntando al proyecto:

- URL: `https://zawaevytpkvejhekyokw.supabase.co`
- anon key: embebida para facilitar dev local.

Para entornos nuevos, preferir `--dart-define`:

```bash
flutter run -d edge \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

## Edge Functions secrets (Supabase Dashboard)

- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`

---

## 10) Comandos de trabajo (Linux/Fedora)

### Migraciones

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase login
supabase link --project-ref zawaevytpkvejhekyokw
supabase db push
```

### App

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride/turnoapp"
flutter pub get
flutter analyze
flutter run -d chrome
```

---

## 11) Smoke test funcional (obligatorio tras cambios)

1) Registro nuevo usuario:
- no permite continuar sin terminos.

2) Home:
- intentar modo conductor sin licencia -> bloquea.

3) Publicar turno:
- obliga punto de encuentro.
- verifica pricing por universidad.

4) Buscar y reservar:
- reserva exitosa + retencion de saldo.

5) Mis reservas:
- boton "ME SUBI AL AUTO" funciona.
- reportar no-show antes de 10 min debe fallar con mensaje.

6) Mis turnos conductor:
- cancelar ride aplica refund pasajeros.
- evalua strike/suspension.

7) Wallet:
- crear topup intent.
- webhook MP acredita (idempotente).

---

## 12) Pendientes priorizados (para terminar proyecto)

## P0 (alto impacto corto plazo)

- Crear pantalla `Mi Perfil` editable (foto, auto, patente, contacto emergencia).
- Ajustar UX de politicas y mensajes de strikes (copy legal definitivo).
- Agregar flujo de actualizacion de `rating_avg`/`rating_count` con review post-viaje.
- Resolver warnings deprecados (`DropdownButtonFormField.value`, `Switch.activeColor`).

## P1 (siguiente iteracion)

- Integrar Fintoc como proveedor alternativo de recarga.
- Implementar multas monetarias explicitas (si negocio lo confirma) y ledger asociado.
- Boton panico real con `url_launcher` (`tel:133`) + registro de evento.

## P2 (largo alcance)

- Live chat (tabla mensajes + realtime + moderacion).
- Favoritos de conductores/turnos + ranking.
- Tema oscuro negro completo.

---

## 13) Riesgos tecnicos conocidos

- No hay suite de tests automatizados completa (predomina validacion manual).
- Fallback local de referencias (universidades/campus) puede enmascarar problemas de RLS en QA.
- Defaults de Supabase en frontend facilitan desarrollo, pero conviene externalizar en release para multi-entorno.
- Algunas decisiones de reglas (por ejemplo, condicion exacta de strike por cancelacion tardia) deben validarse con negocio legal.

---

## 14) Decision log rapido (para IA)

- Se priorizo funcionalidad legal/operativa sobre features pesadas.
- Se dejo fuera chat/favoritos/dark completo por tiempo y complejidad.
- Se eligio enforcement de pricing en DB (trigger) para evitar drift entre frontend y backend.

---

## 15) Checklist para cualquier IA al retomar

1. Leer este archivo completo.
2. Confirmar `supabase db push` sin pendientes.
3. Ejecutar smoke test de la seccion 11.
4. Abrir issues por cada pendiente P0/P1/P2 con criterio de aceptacion.
5. Hacer cambios en ramas pequenas, validando `flutter analyze` + flujo manual.

## Nota de arquitectura beta (Mar 2026)

- Se introdujo capa de estado con Riverpod en flujos criticos (`wallet`, `search`, `my_rides`, `driver_rides`).
- Servicios existentes se mantienen para retrocompatibilidad y migracion incremental.
- El siguiente paso recomendado es migrar `home_screen` y `publish_ride` a providers para eliminar `setState` en flujo core.

---

## 16) Contacto funcional interno (referencia)

- Product owner/origen idea: Agustin Puelma y socios.
- Arquitectura/codigo: Matias Toledo (catalystxzr).

Fin del handoff.
