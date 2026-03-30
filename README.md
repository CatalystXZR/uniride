# TurnoApp

Plataforma de carpooling para estudiantes universitarios en Chile. Conecta conductores y pasajeros que comparten el trayecto entre sus comunas y sus campus.

Construida como **Flutter Web PWA** con backend en **Supabase**.

---

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3.29+ (Web PWA) |
| Backend | Supabase (Postgres + Auth + Edge Functions) |
| Navegación | go_router 13 |
| Estado frontend | Riverpod |
| Pagos | Mercado Pago Checkout Pro |
| Fuente | Google Fonts — Inter |
| Deploy frontend | Vercel |
| Deploy backend | Supabase Cloud |

---

## Flujo principal

```
Registro
  └─ Perfil + billetera creados automáticamente (DB trigger)

Home
  ├─ Modo Conductor
  │   ├─ Publicar turno
  │   └─ Ver mis turnos + pasajeros
  └─ Modo Pasajero
      ├─ Buscar turnos (filtros: comuna, campus, dirección, fecha)
      ├─ Reservar (fondos retenidos atómicamente en la DB)
      ├─ "ME SUBÍ AL AUTO" → pago liberado al conductor
      └─ Cancelar reserva → reembolso inmediato

Billetera
  ├─ Recargar vía Mercado Pago
  └─ Solicitar retiro (mín. $20.000 CLP, procesado manualmente quincenal)
```

---

## Estructura del proyecto

```
uniride/
├── turnoapp/                  # App Flutter
│   └── lib/
│       ├── main.dart
│       ├── app/               # Router + Theme
│       ├── core/              # Constantes + cliente Supabase
│       ├── models/            # Ride, Booking, Wallet, UserProfile, Enums
│       ├── services/          # Auth, Profile, Ride, Booking, Wallet, Withdrawal
│       ├── providers/         # Estado global (Riverpod)
│       └── features/
│           ├── auth/          # Login, Registro
│           ├── profile_switch/# Home (switch conductor/pasajero)
│           ├── rides_publish/ # Publicar turno
│           ├── rides_search/  # Buscar turnos
│           ├── booking/       # Detalle y reserva
│           ├── wallet/        # Billetera y recargas
│           └── my_rides/      # Mis reservas (pasajero) + Mis turnos (conductor)
└── supabase/
    ├── migrations/            # 13 migraciones en orden
    └── functions/
        ├── create-topup-intent/   # Crea preferencia Mercado Pago
        └── mercadopago-webhook/   # Recibe y verifica pagos de MP
```

---

## Variables de entorno

### Flutter (dart-define al hacer build)

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### Supabase Edge Functions (Dashboard → Settings → Edge Functions → Secrets)

| Variable | Descripción |
|---|---|
| `MP_ACCESS_TOKEN` | Access token de Mercado Pago (`APP_USR-...`) |
| `APP_BASE_URL` | URL pública de la app, ej: `https://turnoapp.vercel.app` |
| `MP_WEBHOOK_SECRET` | Secret del webhook de MP para verificación HMAC |

---

## Setup local

```bash
# 1. Instalar dependencias Flutter
cd turnoapp && flutter pub get

# 2. Correr en Chrome
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# 3. Build de producción
flutter build web --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

---

## Base de datos

13 migraciones en `supabase/migrations/`:

| # | Archivo | Contenido |
|---|---|---|
| 00 | `_schema.sql` | 9 tablas, enums, índices |
| 01 | `_rls.sql` | Políticas Row Level Security |
| 02 | `_functions.sql` | RPCs: `create_booking`, `confirm_boarding`, `cancel_booking` |
| 03 | `_auth_trigger.sql` | Trigger: crea perfil + billetera al registrarse |
| 04 | `_seed.sql` | 5 universidades y 14 campus con UUIDs fijos |
| 05 | `_webhook_rpc.sql` | RPC `credit_wallet_topup` |
| 06 | `_public_grants.sql` | `GRANT SELECT` en tablas públicas al rol `anon` |
| 07 | `_reference_rls.sql` | RLS + política pública en `universities` y `campuses` |
| 08 | `_reference_diag.sql` | Diagnóstico de acceso a referencias |
| 09 | `_compliance_pricing_strikes.sql` | Pricing, compliance y strikes |
| 10 | `_profile_photos_storage.sql` | Storage público de fotos de perfil |
| 11 | `_driver_vehicle_required.sql` | Reglas obligatorias para datos de vehículo |
| 12 | `_beta_observability_scalability.sql` | Índices beta + métricas + conciliación wallet |

Para aplicar:
```bash
supabase link --project-ref TU_PROJECT_ID
supabase db push
```

---

## Reglas de negocio MVP

- Precio fijo por asiento: **$2.000 CLP**
- Comunas de origen: Chicureo, Lo Barnechea, Providencia, Vitacura, La Reina, Buin
- Universidades: UDD, U. Andes, PUC, UAI, UNAB
- Retiro mínimo: **$20.000 CLP** (procesado manualmente, quincenal)
- Comisión de plataforma: **$0** en MVP (`platform_fee = 0`)
- Los fondos del pasajero quedan **retenidos** al reservar y se **liberan al conductor** solo cuando el pasajero confirma el abordaje

---

## Documento formal completo

Para una vista integral (producto + arquitectura + decisiones + operacion) revisar:

- `PROJECT_BRIEF_COMPLETE.md`

Este documento esta preparado para:
- onboarding tecnico de IAs y desarrolladores,
- presentacion ejecutiva/funcional a personas no tecnicas.

---
