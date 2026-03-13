# TurnoApp — Contexto completo para retomar con una IA

Copia y pega este archivo completo al inicio de una nueva conversación con una IA para que quede al tanto de todo.

---

## Qué es esto

**TurnoApp** es una app de coordinación de carpooling para estudiantes universitarios en Chile.
Está construida como una **Flutter Web PWA** con backend en **Supabase**.

- Directorio raíz del proyecto: `/home/catalystxzr/Escritorio/uniride/`
- La app Flutter está en: `turnoapp/`
- El backend Supabase está en: `supabase/`

---

## Stack técnico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter Web (PWA), mobile-first |
| Backend | Supabase (Postgres + Auth + Edge Functions + Realtime) |
| Navegación | go_router ^13.2.0 |
| UI | Material 3, google_fonts |
| Pagos | Mercado Pago Checkout Pro |
| Internacionalización | intl ^0.19.0 |

**Dependencias en `pubspec.yaml` (limpias, sin paquetes muertos):**
```yaml
dependencies:
  flutter: sdk: flutter
  supabase_flutter: ^2.5.0
  go_router: ^13.2.0
  google_fonts: ^6.2.1
  cupertino_icons: ^1.0.6
  intl: ^0.19.0
  url_launcher: ^6.3.0
```

Paquetes eliminados (estaban en pubspec pero nunca se usaban y rompían builds):
`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`,
`firebase_core`, `firebase_messaging`, `shared_preferences`

---

## Reglas de negocio MVP

- **Universidades soportadas:** UDD, U. Andes, PUC, UAI, UNAB
- **Comunas de origen permitidas:** Chicureo, Lo Barnechea, Providencia, Vitacura, La Reina, Buin
- **Precio fijo por asiento:** $2.000 CLP
- **Retiro mínimo:** $20.000 CLP (manual, quincenal)
- **Flujo central:**
  1. Registro → perfil creado automáticamente por DB trigger
  2. Usuario cambia modo Conductor / Pasajero en HomeScreen
  3. Conductor publica viaje
  4. Pasajero busca y reserva (fondos retenidos atómicamente vía RPC `create_booking`)
  5. Pasajero presiona "ME SUBÍ AL AUTO" → RPC `confirm_boarding` libera fondos al conductor
  6. Billetera se recarga vía Mercado Pago → webhook Edge Function → RPC `credit_wallet_topup`

---

## Estructura de archivos relevante

```
uniride/
├── DEPLOY.md                          # Guía paso a paso de despliegue
├── CONTEXTO_IA.md                     # Este archivo
├── .env.example
├── turnoapp/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart                  # initializeDateFormatting('es') aquí
│       ├── app/
│       │   ├── app.dart
│       │   ├── router.dart            # GoRouter, StreamSubscription con dispose()
│       │   └── theme.dart
│       ├── core/
│       │   ├── constants.dart         # AppConstants.allowedCommunes, seatPriceCLP
│       │   └── supabase_client.dart
│       ├── models/
│       │   ├── enums.dart             # RideDirection, BookingStatus, RoleMode
│       │   ├── user_profile.dart
│       │   ├── ride.dart
│       │   ├── booking.dart
│       │   ├── wallet.dart
│       │   └── transaction.dart
│       ├── services/
│       │   ├── auth_service.dart
│       │   ├── profile_service.dart
│       │   ├── ride_service.dart
│       │   ├── booking_service.dart   # cancelBooking() + getBookingsForMyRides() (two-step query)
│       │   ├── wallet_service.dart    # createTopupIntent() con manejo de errores
│       │   └── withdrawal_service.dart
│       └── features/
│           ├── auth/
│           │   ├── login_screen.dart
│           │   └── register_screen.dart   # carga universidades desde DB con UUIDs reales
│           ├── profile_switch/
│           │   └── home_screen.dart       # navega a /driver-rides
│           ├── rides_publish/
│           │   └── publish_ride_screen.dart
│           ├── rides_search/
│           │   └── search_rides_screen.dart  # _FilterChipDropdown con _displayLabel fix
│           ├── booking/
│           │   └── booking_screen.dart    # usa ride.seatPrice (no hardcoded)
│           ├── wallet/
│           │   └── wallet_screen.dart     # input de monto en retiro
│           └── my_rides/
│               ├── my_rides_screen.dart   # botón cancelar + withValues(alpha:)
│               └── driver_rides_screen.dart  # NUEVO — vista del conductor
└── supabase/
    ├── config.toml
    ├── migrations/
    │   ├── 00000000000000_schema.sql      # tablas, enums, índices
    │   ├── 00000000000001_rls.sql         # RLS policies
    │   ├── 00000000000002_functions.sql   # RPCs: create_booking, confirm_boarding, cancel_booking
    │   ├── 00000000000003_auth_trigger.sql # trigger: crea perfil+billetera al registrarse
    │   ├── 00000000000004_seed.sql        # universidades y campus con UUIDs fijos
    │   ├── 00000000000005_webhook_rpc.sql # RPC credit_wallet_topup
    │   ├── 00000000000006_public_grants.sql # GRANT SELECT ON universities, campuses
    │   └── 00000000000007_reference_rls.sql # RLS + policy FOR SELECT USING(true) en universities/campuses
    └── functions/
        ├── create-topup-intent/index.ts   # crea preferencia MP, notification_url derivada de SUPABASE_URL
        └── mercadopago-webhook/index.ts   # verifica HMAC-SHA256, idempotencia, llama credit_wallet_topup
```

---

## Base de datos — UUIDs del seed (fijos)

### Universidades
| UUID | Código | Nombre |
|---|---|---|
| `11111111-0000-0000-0000-000000000001` | UDD | Universidad del Desarrollo |
| `11111111-0000-0000-0000-000000000002` | UANDES | Universidad de los Andes |
| `11111111-0000-0000-0000-000000000003` | PUC | Pontificia Universidad Católica de Chile |
| `11111111-0000-0000-0000-000000000004` | UAI | Universidad Adolfo Ibáñez |
| `11111111-0000-0000-0000-000000000005` | UNAB | Universidad Andrés Bello |

### Campus (selección relevante)
| UUID | Universidad | Campus | Comuna |
|---|---|---|---|
| `22222222-0001-0000-0000-000000000002` | UDD | Campus Las Condes | Las Condes |
| `22222222-0002-0000-0000-000000000001` | UANDES | Campus San Carlos de Apoquindo | Las Condes |
| `22222222-0003-0000-0000-000000000001` | PUC | Campus San Joaquín | San Joaquín |
| `22222222-0003-0000-0000-000000000002` | PUC | Campus Casa Central | Santiago |
| `22222222-0003-0000-0000-000000000003` | PUC | Campus Lo Contador | Providencia |
| `22222222-0004-0000-0000-000000000001` | UAI | Campus Peñalolén | Peñalolén |
| `22222222-0004-0000-0000-000000000002` | UAI | Campus Vitacura | Vitacura |
| `22222222-0005-0000-0000-000000000001` | UNAB | Campus República | Santiago |

---

## RPCs de Postgres (security definer)

### `create_booking(p_ride_id uuid) → uuid`
- Bloquea el ride con `FOR UPDATE`
- Valida asientos disponibles y estado `active`
- Deduce `seat_price` de `balance_available` del pasajero y lo mueve a `balance_held`
- Decrementa `seats_available`
- Inserta booking + transacción `booking_hold`
- Error codes: `P0001` unauthorized, `P0002` ride unavailable, `P0003` already booked, `P0004` insufficient balance

### `confirm_boarding(p_booking_id uuid) → void`
- Solo puede llamarla el pasajero dueño del booking
- Mueve fondos de `balance_held` del pasajero a `balance_available` del conductor
- Marca booking como `completed`
- Inserta dos filas en `transactions`: una para el pasajero (`release_to_driver`, amount=0) y una para el conductor (amount=price)

### `cancel_booking(p_booking_id uuid) → void`
- Devuelve `balance_held` → `balance_available` del pasajero
- Restaura `seats_available` en el ride
- Marca booking como `cancelled`
- Inserta transacción de tipo `refund`

### `credit_wallet_topup(p_user_id, p_amount, p_external_payment_id) → void`
- Acredita recarga de billetera
- Inserta en `mp_payments` para idempotencia (primary key = external_payment_id)
- Inserta transacción tipo `topup`

---

## Variables de entorno requeridas (Supabase Dashboard → Edge Functions)

| Variable | Descripción |
|---|---|
| `MP_ACCESS_TOKEN` | Access token de Mercado Pago (APP_USR-...) |
| `APP_BASE_URL` | URL pública de la app, ej: `https://turnoapp.cl` |
| `MP_WEBHOOK_SECRET` | Shared secret del dashboard de MP para verificación HMAC |
| `SUPABASE_URL` | Inyectada automáticamente por Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Inyectada automáticamente por Supabase |

---

## Bugs corregidos (todos resueltos)

| # | Descripción | Archivo |
|---|---|---|
| BUG-01 | `StreamSubscription` leak en GoRouter | `router.dart` |
| BUG-02 | `createTopupIntent` sin manejo de errores | `wallet_service.dart` |
| BUG-03 | `getBookingsForMyRides()` filtro PostgREST silencioso | `booking_service.dart` |
| GAP-01 | Vista "Mis turnos publicados" del conductor no existía | `driver_rides_screen.dart` (nuevo) |
| GAP-02 | Dropdown de universidades no guardaba UUID real | `register_screen.dart` |
| GAP-03 | Diálogo de retiro sin input de monto | `wallet_screen.dart` |
| GAP-04 | Locale español no inicializado para `DateFormat` | `main.dart` |
| GAP-05 | `booking_screen.dart` usaba precio hardcodeado | `booking_screen.dart` |
| SEC-01 | Webhook sin verificación HMAC | `mercadopago-webhook/index.ts` |
| DEAD | Deps muertos (riverpod, firebase, shared_prefs) | `pubspec.yaml` |
| MINOR-01 | `withOpacity()` deprecado en Flutter 3.27+ | `my_rides_screen.dart` |
| MINOR-03 | `_FilterChipDropdown` siempre mostraba placeholder | `search_rides_screen.dart` |
| MINOR-05 | `notification_url` apuntaba a URL incorrecta | `create-topup-intent/index.ts` |
| DB-01 | `universities`/`campuses` sin RLS policy pública | migración `07_reference_rls.sql` |
| DB-02 | Sin `GRANT SELECT` para rol `anon` en tablas públicas | migración `06_public_grants.sql` |

---

## Pendiente / próximos pasos sugeridos

1. **Correr migración 07 en Supabase** (si no se ha hecho):
   ```sql
   ALTER TABLE universities ENABLE ROW LEVEL SECURITY;
   DROP POLICY IF EXISTS "universities_public_read" ON universities;
   CREATE POLICY "universities_public_read" ON universities FOR SELECT USING (true);
   ALTER TABLE campuses ENABLE ROW LEVEL SECURITY;
   DROP POLICY IF EXISTS "campuses_public_read" ON campuses;
   CREATE POLICY "campuses_public_read" ON campuses FOR SELECT USING (true);
   ```

2. **Verificar el dropdown de universidades** en la pantalla de registro — debe cargar la lista. Si falla, ahora muestra un botón "Reintentar" con el error real en consola.

3. **Build y despliegue:**
   ```bash
   cd turnoapp
   flutter pub get
   flutter build web --release
   ```
   Luego subir `build/web/` a Firebase Hosting, Vercel, Netlify, o cualquier hosting estático.

4. **Configurar Mercado Pago:** Agregar `MP_ACCESS_TOKEN`, `APP_BASE_URL`, `MP_WEBHOOK_SECRET` en Supabase Dashboard → Project Settings → Edge Functions → Secrets.

5. **Desplegar Edge Functions:**
   ```bash
   supabase functions deploy create-topup-intent
   supabase functions deploy mercadopago-webhook
   ```

---

## ID de usuario del dueño del proyecto

`2bb87b61-351d-4934-b562-c65e28d037b4`

(Usado para insertar viajes de prueba directamente en la DB)

---

## SQL para insertar viajes de prueba (ya ejecutado)

```sql
INSERT INTO users_profile (id, full_name, role_mode, is_driver_verified)
VALUES ('2bb87b61-351d-4934-b562-c65e28d037b4', 'Conductor Test', 'driver', true)
ON CONFLICT (id) DO UPDATE SET role_mode = 'driver', is_driver_verified = true;

INSERT INTO wallets (user_id, balance_available, balance_held)
VALUES ('2bb87b61-351d-4934-b562-c65e28d037b4', 0, 0)
ON CONFLICT (user_id) DO NOTHING;

-- Viaje 1: Chicureo → PUC San Joaquín
INSERT INTO rides (driver_id, university_id, campus_id, origin_commune, direction, departure_at, seat_price, seats_total, seats_available)
VALUES ('2bb87b61-351d-4934-b562-c65e28d037b4','11111111-0000-0000-0000-000000000003','22222222-0003-0000-0000-000000000001','Chicureo','to_campus',NOW() + INTERVAL '1 day' + INTERVAL '7 hours 30 minutes',2000,4,4);

-- Viaje 2: Lo Barnechea → UAI Vitacura
INSERT INTO rides (driver_id, university_id, campus_id, origin_commune, direction, departure_at, seat_price, seats_total, seats_available)
VALUES ('2bb87b61-351d-4934-b562-c65e28d037b4','11111111-0000-0000-0000-000000000004','22222222-0004-0000-0000-000000000002','Lo Barnechea','to_campus',NOW() + INTERVAL '2 days' + INTERVAL '8 hours',2000,3,3);

-- Viaje 3: Providencia → UDD Las Condes (desde campus)
INSERT INTO rides (driver_id, university_id, campus_id, origin_commune, direction, departure_at, seat_price, seats_total, seats_available)
VALUES ('2bb87b61-351d-4934-b562-c65e28d037b4','11111111-0000-0000-0000-000000000001','22222222-0001-0000-0000-000000000002','Providencia','from_campus',NOW() + INTERVAL '5 hours',2000,2,2);
```
