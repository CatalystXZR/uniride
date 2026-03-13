# TurnoApp — Dossier Técnico

> **Project:** TurnoApp  
> **Original Concept:** Agustín Puelma & Partners  
> **Software Architecture & Code:** Matías Toledo (catalystxzr)  
> **Copyright (c) 2026. All rights reserved.**

---

## 1. Visión General

TurnoApp es una PWA (Progressive Web App) de carpooling universitario para Chile. Conecta estudiantes que viven en las mismas comunas con conductores que van al mismo campus, permitiendo reservar y pagar asientos directamente desde el celular. El MVP está enfocado en cinco universidades del sector oriente/norte de Santiago.

| Dimensión | Detalle |
|---|---|
| Plataforma | Flutter Web (compilado a HTML/JS/CSS), deployado como PWA |
| Frontend host | Vercel |
| Backend | Supabase (Postgres 15, Auth, Edge Functions en Deno) |
| Pagos | Mercado Pago Checkout Pro (v1) |
| Precio por asiento | $2.000 CLP (fijo, MVP) |
| Retiro mínimo | $20.000 CLP |
| Comisión plataforma | $0 (MVP) |

---

## 2. Arquitectura de Alto Nivel

```
┌─────────────────────────────────────────┐
│  Flutter Web PWA (Vercel)               │
│  ┌──────────┐  ┌──────────┐             │
│  │ Features │  │ Services │             │
│  │ (screens)│→ │ (dart)   │             │
│  └──────────┘  └────┬─────┘             │
└───────────────────── │ ─────────────────┘
                        │ HTTPS / JWT
          ┌─────────────▼──────────────────┐
          │  Supabase Cloud                │
          │                                │
          │  ┌───────────┐  ┌───────────┐  │
          │  │  Postgres  │  │   Auth    │  │
          │  │  + RLS     │  │  (email)  │  │
          │  └─────┬──────┘  └───────────┘  │
          │        │ SECURITY DEFINER RPCs   │
          │  ┌─────▼──────────────────────┐  │
          │  │  Edge Functions (Deno/TS)  │  │
          │  │  create-topup-intent       │  │
          │  │  mercadopago-webhook       │  │
          │  └────────────┬───────────────┘  │
          └───────────────│─────────────────┘
                          │ HTTPS
          ┌───────────────▼──────────┐
          │  Mercado Pago API        │
          │  Checkout Pro            │
          └──────────────────────────┘
```

---

## 3. Estructura del Repositorio

```
uniride/
├── README.md
├── DEPLOY.md
├── CONTEXTO_IA.md
├── DOSSIER_TECNICO.md          ← este archivo
├── .env.example
├── turnoapp/                   ← app Flutter
│   ├── pubspec.yaml
│   ├── web/
│   │   ├── index.html
│   │   └── manifest.json
│   └── lib/
│       ├── main.dart
│       ├── app/
│       │   ├── app.dart        ← TurnoApp widget raíz
│       │   ├── router.dart     ← GoRouter + auth guard
│       │   └── theme.dart      ← MaterialTheme con Google Fonts
│       ├── core/
│       │   ├── constants.dart  ← precios, comunas, universidades
│       │   └── supabase_client.dart
│       ├── models/
│       │   ├── enums.dart
│       │   ├── user_profile.dart
│       │   ├── ride.dart
│       │   ├── booking.dart
│       │   ├── wallet.dart
│       │   └── transaction.dart
│       ├── services/
│       │   ├── auth_service.dart
│       │   ├── profile_service.dart
│       │   ├── ride_service.dart
│       │   ├── booking_service.dart
│       │   ├── wallet_service.dart
│       │   └── withdrawal_service.dart
│       ├── features/
│       │   ├── auth/
│       │   │   ├── login_screen.dart
│       │   │   └── register_screen.dart
│       │   ├── profile_switch/
│       │   │   └── home_screen.dart
│       │   ├── rides_publish/
│       │   │   └── publish_ride_screen.dart
│       │   ├── rides_search/
│       │   │   └── search_rides_screen.dart
│       │   ├── booking/
│       │   │   └── booking_screen.dart
│       │   ├── wallet/
│       │   │   └── wallet_screen.dart
│       │   └── my_rides/
│       │       ├── my_rides_screen.dart      ← vista pasajero
│       │       └── driver_rides_screen.dart  ← vista conductor
│       └── shared/widgets/
│           ├── turno_card.dart
│           ├── loading_overlay.dart
│           └── app_snackbar.dart
└── supabase/
    ├── migrations/             ← 8 migraciones SQL en orden
    └── functions/
        ├── create-topup-intent/index.ts
        └── mercadopago-webhook/index.ts
```

---

## 4. Modelo de Datos (Postgres)

### Tablas

| Tabla | Descripción |
|---|---|
| `universities` | Catálogo de universidades (UDD, PUC, UAI, UANDES, UNAB) |
| `campuses` | Campus de cada universidad con su comuna |
| `users_profile` | Perfil extendido de cada usuario (1-to-1 con `auth.users`) |
| `wallets` | Saldo disponible y retenido de cada usuario (CLP enteros) |
| `rides` | Viajes publicados por conductores |
| `bookings` | Reservas de pasajeros sobre viajes |
| `transactions` | Ledger inmutable de movimientos de dinero |
| `withdrawals` | Solicitudes de retiro de conductores |
| `strikes` | Penalizaciones aplicadas a conductores |
| `mp_payments` | Idempotencia de pagos de Mercado Pago |

### Enums (definidos en Postgres)

| Enum | Valores |
|---|---|
| `role_mode` | `passenger`, `driver` |
| `ride_direction` | `to_campus`, `from_campus` |
| `booking_status` | `reserved`, `cancelled`, `completed`, `no_show` |
| `tx_type` | `topup`, `booking_hold`, `release_to_driver`, `platform_fee`, `refund`, `withdrawal_request`, `withdrawal_paid`, `penalty` |

### Invariantes clave

- `wallets.balance_available >= 0` y `wallets.balance_held >= 0` — check constraints en Postgres.
- `transactions` es append-only: dos reglas SQL (`ON UPDATE/DELETE DO INSTEAD NOTHING`) previenen modificaciones.
- `mp_payments.external_payment_id` es PRIMARY KEY — impide doble acreditación del mismo pago.
- `bookings(ride_id, passenger_id)` tiene constraint UNIQUE — un pasajero no puede reservar el mismo viaje dos veces.

---

## 5. Row Level Security (RLS)

Todas las tablas tienen RLS activado. Política general:

| Tabla | Lectura | Escritura |
|---|---|---|
| `universities`, `campuses` | Cualquiera (incluido `anon`) | Solo `service_role` (migraciones) |
| `users_profile` | Propio usuario | Propio usuario |
| `wallets` | Propio usuario | Solo vía RPC (`SECURITY DEFINER`) |
| `rides` | Cualquier autenticado | Solo el conductor dueño |
| `bookings` | Propio usuario (como pasajero o conductor del viaje) | Solo vía RPC |
| `transactions` | Propio usuario | Solo vía RPC (ledger inmutable) |
| `withdrawals` | Propio conductor | Solo vía servicio (insert) |
| `mp_payments` | Nadie (solo `service_role`) | Solo Edge Function webhook |

**Nota importante:** `universities` y `campuses` requieren tanto `GRANT SELECT TO anon` (migración 06) como una política RLS `FOR SELECT USING (true)` (migración 07). Solo uno de los dos no es suficiente cuando el Supabase Dashboard tiene RLS habilitado.

---

## 6. Funciones RPC (SECURITY DEFINER)

Todas las operaciones financieras ocurren en funciones Postgres con `SECURITY DEFINER` para garantizar atomicidad y bypass de RLS controlado.

### `create_booking(p_ride_id uuid) → uuid`

1. Verifica autenticación (`auth.uid()`).
2. Bloquea el row del viaje (`FOR UPDATE`) y valida disponibilidad.
3. Verifica que el pasajero no tenga ya una reserva activa en ese viaje.
4. Deduce `seat_price` de `balance_available` y lo agrega a `balance_held` — falla si saldo insuficiente.
5. Decrementa `seats_available` en el viaje.
6. Crea el row en `bookings`.
7. Inserta una entrada `booking_hold` (negativa) en `transactions`.
8. Retorna el UUID de la nueva reserva.

### `confirm_boarding(p_booking_id uuid) → void`

Triggered cuando el pasajero confirma "Me subí al auto".

1. Bloquea el booking y obtiene pasajero, conductor y monto.
2. Verifica que el caller es el pasajero.
3. Mueve `amount` de `balance_held` del pasajero a `balance_available` del conductor.
4. Marca el booking como `completed`.
5. Inserta dos entradas en `transactions` (una por cada parte).

### `cancel_booking(p_booking_id uuid) → void`

1. Reembolsa el monto retenido del pasajero de vuelta a `balance_available`.
2. Restaura el asiento en el viaje.
3. Marca el booking como `cancelled`.
4. Inserta una entrada `refund` en `transactions`.

### `credit_wallet_topup(p_user_id, p_external_id, p_amount)` (migración 05)

Llamada exclusivamente por la Edge Function `mercadopago-webhook`.

1. Inserta en `mp_payments` (falla con constraint si ya existe → idempotencia).
2. Suma `p_amount` a `wallets.balance_available`.
3. Inserta entrada `topup` en `transactions`.

---

## 7. Edge Functions (Deno / TypeScript)

### `create-topup-intent`

- **Trigger:** llamada autenticada del cliente Flutter vía `WalletService.createTopupIntent(amount)`.
- **Función:** crea una preferencia de pago en Mercado Pago Checkout Pro.
- **Seguridad:** extrae y verifica el JWT del header `Authorization` antes de crear la preferencia.
- **`notification_url`:** se auto-deriva de `SUPABASE_URL` (variable inyectada por Supabase runtime), apuntando siempre a la función `mercadopago-webhook` del mismo proyecto.
- **Límites:** mínimo $2.000 CLP, máximo $200.000 CLP por transacción.
- **Retorna:** `{ init_point, sandbox_init_point, preference_id, external_reference }`.

### `mercadopago-webhook`

- **Trigger:** IPN/webhook de Mercado Pago cuando se aprueba un pago.
- **Seguridad:** verifica firma HMAC-SHA256 del header `x-signature` usando `MP_WEBHOOK_SIGNATURE_KEY`.
- **Flujo:**
  1. Valida firma.
  2. Filtra solo eventos `topic=payment` con `status=approved`.
  3. Parsea `external_reference` para extraer `user_id`.
  4. Llama RPC `credit_wallet_topup` — idempotente via `mp_payments`.
- **Variables de entorno:** `MP_ACCESS_TOKEN`, `MP_WEBHOOK_SIGNATURE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

---

## 8. Routing (Flutter / GoRouter)

| Ruta | Screen | Requiere auth |
|---|---|---|
| `/login` | `LoginScreen` | No |
| `/register` | `RegisterScreen` | No |
| `/home` | `HomeScreen` | Sí |
| `/publish` | `PublishRideScreen` | Sí |
| `/search` | `SearchRidesScreen` | Sí |
| `/booking/:rideId` | `BookingScreen` | Sí |
| `/wallet` | `WalletScreen` | Sí |
| `/my-rides` | `MyRidesScreen` (pasajero) | Sí |
| `/driver-rides` | `DriverRidesScreen` (conductor) | Sí |

El guard de autenticación está implementado en el callback `redirect` del `GoRouter`. Escucha cambios en el stream de auth de Supabase via `GoRouterRefreshStream` (un `ChangeNotifier` con `StreamSubscription` que se cancela correctamente en `dispose` para evitar memory leaks).

---

## 9. Capa de Servicios (Flutter)

| Servicio | Responsabilidad |
|---|---|
| `AuthService` | Login, registro, logout, password reset |
| `ProfileService` | Leer/actualizar perfil, cambiar `role_mode`, cargar universidades/campus |
| `RideService` | Publicar viaje, buscar viajes activos con filtros |
| `BookingService` | Crear/cancelar reserva (vía RPC), confirmar boarding, obtener reservas propias y del conductor |
| `WalletService` | Leer saldo, historial de transacciones, iniciar recarga vía Edge Function |
| `WithdrawalService` | Solicitar retiro (valida mínimo $20.000 CLP) |

---

## 10. Migraciones SQL (orden de aplicación)

| # | Archivo | Contenido |
|---|---|---|
| 00 | `_schema.sql` | Extensions, enums, todas las tablas, índices, reglas no-update/delete en `transactions` |
| 01 | `_rls.sql` | Habilita RLS en todas las tablas y define todas las políticas |
| 02 | `_functions.sql` | RPCs: `create_booking`, `confirm_boarding`, `cancel_booking` |
| 03 | `_auth_trigger.sql` | Trigger `on_auth_user_created` → inserta en `users_profile` + `wallets` automáticamente |
| 04 | `_seed.sql` | Datos de universidades y campus para las 5 instituciones |
| 05 | `_webhook_rpc.sql` | RPC `credit_wallet_topup` (para el webhook de MP) |
| 06 | `_public_grants.sql` | `GRANT SELECT ON universities, campuses TO anon, authenticated` |
| 07 | `_reference_rls.sql` | Políticas RLS `FOR SELECT USING (true)` en `universities` y `campuses` |

---

## 11. Decisiones Técnicas Relevantes

### ¿Por qué SECURITY DEFINER RPCs en lugar de mutaciones directas?

Las operaciones de reserva y pago involucran múltiples tablas y deben ser atómicas. Una mutación directa desde el cliente requeriría múltiples round-trips y no garantizaría consistencia. Las RPCs Postgres ejecutan todo en una sola transacción de base de datos bajo un usuario con privilegios elevados, sin exponer esos privilegios al cliente.

### ¿Por qué two-step query en `getBookingsForMyRides()`?

PostgREST no permite filtrar por columnas de tablas relacionadas usando `.eq('rides.driver_id', uid)` — la condición se ignora silenciosamente, devolviendo todos los bookings. La solución correcta es: primero obtener los IDs de viajes del conductor, luego filtrar bookings por esos IDs con `.inFilter('ride_id', rideIds)`.

### ¿Por qué `withValues(alpha:)` en lugar de `withOpacity()`?

`Color.withOpacity()` fue deprecado en Flutter 3.27+ en favor de `Color.withValues(alpha: x)` que opera en el espacio de color correcto. Se actualizaron todas las ocurrencias.

### ¿Por qué `CardThemeData` en lugar de `CardTheme`?

En Flutter 3.29+, `ThemeData.cardTheme` acepta `CardThemeData` (no `CardTheme`). El compilador lanza un error de tipo si se usa el nombre antiguo.

### ¿Por qué `vercel.json` con rewrite?

Flutter Web compila a una SPA con un único `index.html`. Sin un rewrite, Vercel devuelve 404 cuando el usuario refresca una URL como `/wallet`. El `vercel.json` redirige todas las rutas no-asset a `index.html`.

### ¿Por qué idempotencia con `mp_payments`?

Mercado Pago puede enviar el webhook de un mismo pago más de una vez (reintentos). La tabla `mp_payments` con `external_payment_id` como PRIMARY KEY garantiza que la RPC `credit_wallet_topup` falle en el segundo intento con un error de constraint, sin acreditar el saldo dos veces.

### ¿Por qué no Firebase/Riverpod/SharedPreferences?

Estas dependencias fueron añadidas en el scaffolding inicial pero no se usaban en ningún archivo de la app. Se removieron de `pubspec.yaml` para reducir el tamaño del bundle y eliminar warnings en tiempo de compilación.

---

## 12. Variables de Entorno

### Flutter (en `lib/core/supabase_client.dart` o `--dart-define`)

| Variable | Descripción |
|---|---|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_ANON_KEY` | Clave anon pública de Supabase |

### Supabase Edge Functions (Dashboard → Settings → Edge Functions → Secrets)

| Variable | Descripción |
|---|---|
| `MP_ACCESS_TOKEN` | Access token de Mercado Pago (APP_USR-...) |
| `MP_WEBHOOK_SIGNATURE_KEY` | Clave de firma HMAC para verificar webhooks de MP |
| `APP_BASE_URL` | URL pública de la app (e.g. `https://turnoapp.vercel.app`) |

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son inyectadas automáticamente por el runtime de Supabase.

---

## 13. Universidades y Comunas (MVP)

### Universidades

| Código | Nombre |
|---|---|
| UDD | Universidad del Desarrollo |
| UANDES | Universidad de los Andes |
| PUC | Pontificia Universidad Católica |
| UAI | Universidad Adolfo Ibáñez |
| UNAB | Universidad Andrés Bello |

### Comunas de origen permitidas

Chicureo · Lo Barnechea · Providencia · Vitacura · La Reina · Buin

---

## 14. Flujo de Pago Completo

```
Pasajero                    TurnoApp Backend              Mercado Pago
    │                              │                            │
    │── WalletScreen: "Recargar" ──►                            │
    │                              │── create preference ──────►│
    │                              │◄── { init_point } ─────────│
    │◄── redirigir a init_point ───│                            │
    │                              │                            │
    │── paga en MP ────────────────────────────────────────────►│
    │                              │◄── webhook (IPN) ──────────│
    │                              │   verificar HMAC-SHA256     │
    │                              │   credit_wallet_topup RPC   │
    │                              │   (idempotente)             │
    │◄── redirect back_url ────────────────────────────────────-│
    │── GET /wallet ───────────────►                            │
    │◄── saldo actualizado ─────────                            │
```

---

## 15. Estado del Proyecto

| Componente | Estado |
|---|---|
| Base de datos (schema + RLS + RPCs) | Producción |
| Auth (email/password) | Producción |
| Publicar viajes | Producción |
| Buscar y reservar viajes | Producción |
| Billetera + recarga MP | Producción |
| Vista conductor (mis viajes + pasajeros) | Producción |
| Vista pasajero (mis reservas) | Producción |
| Retiros | MVP (manual/quincenal) |
| Notificaciones push | No implementado (post-MVP) |
| App nativa (iOS/Android) | No implementado (post-MVP) |
| Deep links para MP en mobile | No implementado (post-MVP) |
