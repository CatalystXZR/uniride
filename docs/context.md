# TurnoApp - Contexto de Producto (Resumen Operativo)

## Actualización de alcance MVP (obligatorio)

- Nombre de la app: **TurnoApp**
- Objetivo: reemplazar grupos informales de WhatsApp para coordinar "turnos".
- Cobertura universidades: **UDD, U Andes, PUC, UAI, UNAB**
- Modalidad: **PWA mobile-first** con UX tipo ride-hailing (simple y rápida).
- Perfiles: switch en app entre **Conductor** y **Pasajero**.
- Flujo principal:
  - Publicar turno (ida o vuelta)
  - Buscar turno por universidad/campus/comuna/hora
  - Reservar asiento
  - Retención de pago y liberación con botón **"ME SUBÍ AL AUTO"**
- Comunas permitidas:
  - Chicureo
  - Lo Barnechea
  - Providencia
  - Vitacura
  - La Reina
  - Buin
- Billetera virtual:
  - Recarga con Mercado Pago
  - Descuento automático por reserva
  - Sin transferencias manuales entre usuarios
- Tarifa MVP por viaje: **$2.000 CLP**

## Nota de consistencia de pricing

Para el prototipo técnico actual, usar **$2.000 CLP** como valor base por asiento en booking, retención y liberación a conductor.
Cualquier comisión de plataforma adicional puede modelarse luego como parámetro configurable (`platform_fee`) sin romper el flujo MVP.

## Consideraciones Técnicas

- **Stack Tecnológico**: Definir si se usará un stack nativo (Swift/Kotlin) o uno híbrido (React Native, Flutter).
- **Base de Datos**: Evaluar entre Firebase (tiempo real, fácil escalado) o una base de datos SQL tradicional (mayor control, consultas complejas).
- **Geolocalización**: Integrar con Google Maps API o Mapbox para la funcionalidad de ubicación en tiempo real.
- **Notificaciones Push**: Implementar para alertar a los usuarios sobre nuevos turnos, mensajes, o actualizaciones importantes.
- **Seguridad**: Asegurar la información sensible con encriptación y cumplir con normativas locales de protección de datos.

## Estrategia de Lanzamiento

- **Reclutamiento 1 a 1 (Los "Power Users")**: Identificar y contactar a estudiantes que frecuentemente ofrecen su auto, para que prueben la app y den feedback.
- **Mensaje "Caballo de Troya" (Para el grupo masivo)**: Una vez que haya al menos 5 autos en la app, enviar un mensaje al grupo grande destacando la facilidad y seguridad de la app.
- **Gancho de la Billetera (Para los pasajeros)**: Ofrecer un incentivo, como un saldo adicional en la billetera, para que los pasajeros realicen su primera recarga y usen la app.

## Feedback y Iteración

- **Recolección de Feedback**: Implementar una encuesta dentro de la app para recoger opiniones de usuarios sobre la experiencia, problemas encontrados y sugerencias.
- **Métricas Clave**: Monitorear la tasa de retención de usuarios, número de viajes coordinados, y saldo promedio en billeteras para evaluar la salud del negocio.
- **Mejoras Continuas**: Establecer un ciclo de desarrollo ágil para ir incorporando mejoras y nuevas funcionalidades basadas en el feedback recibido.

## Expansión y Escalabilidad

- **Nuevas Universidades**: Una vez validado el modelo en las universidades actuales, planificar la expansión a otras instituciones de educación superior.
- **Funcionalidades Adicionales**: Considerar la incorporación de servicios complementarios como seguros de viaje, o la posibilidad de dejar evaluaciones y comentarios entre usuarios.
- **Alianzas Estratégicas**: Buscar alianzas con empresas de transporte público o privado para ofrecer tarifas preferenciales a los usuarios de la app.

## Riesgos y Mitigaciones

- **Baja Adopción**: Si la app no es adoptada rápidamente, considerar campañas de marketing más agresivas o re-evaluar el modelo de negocio.
- **Problemas Técnicos**: Tener un plan de contingencia para caídas del sistema o problemas con procesadores de pago.
- **Competencia**: Estar atentos a movimientos de la competencia y tener siempre un plan de diferenciación claro.

## Conclusión

TurnoApp tiene el potencial de transformar la manera en que los estudiantes coordinan sus viajes hacia y desde la universidad. Con un enfoque en la simplicidad, seguridad y eficiencia, la app no solo resolverá problemas actuales de movilidad, sino que también creará una comunidad más unida y colaborativa.

## Arquitectura Serverless (Low-Cost) - Diseño Final MVP

### 1) Arquitectura del sistema

- **Frontend**: Flutter Web (PWA mobile-first), 1 solo código para Android/iOS/Web.
- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions + Realtime).
- **Pagos**: Mercado Pago Checkout Pro para recarga de billetera.
- **Push**: FCM (solo eventos críticos para ahorrar costo).
- **Mapas**: iniciar sin tracking en tiempo real; solo puntos de encuentro + geocoding básico.
- **Observabilidad barata**: logs en Supabase + dashboard SQL interno.

Flujo:
1. Usuario se registra/login (Supabase Auth).
2. Completa perfil + alterna modo Conductor/Pasajero (switch UI).
3. Conductor publica turno (ida/vuelta) con cupos.
4. Pasajero reserva; función SQL descuenta saldo y retiene fondos.
5. Pasajero confirma “ME SUBÍ AL AUTO”; función libera pago al conductor.
6. Conductor solicita retiro; operación queda en cola/manual (quincenal) para evitar automatización cara inicial.

---

### 2) PostgreSQL schema (MVP)

```sql
create extension if not exists "pgcrypto";

create type role_mode as enum ('passenger','driver');
create type ride_direction as enum ('to_campus','from_campus');
create type booking_status as enum ('reserved','cancelled','completed','no_show');
create type tx_type as enum (
  'topup','booking_hold','release_to_driver','platform_fee',
  'refund','withdrawal_request','withdrawal_paid','penalty'
);

create table if not exists universities (
  id uuid primary key default gen_random_uuid(),
  code text unique not null, -- UDD, UANDES, PUC, UAI, UNAB
  name text not null
);

create table if not exists campuses (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references universities(id),
  name text not null,
  commune text not null
);

create table if not exists users_profile (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  university_id uuid references universities(id),
  campus_id uuid references campuses(id),
  role_mode role_mode not null default 'passenger',
  is_driver_verified boolean not null default false,
  strikes_count int not null default 0,
  suspended_until timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists wallets (
  user_id uuid primary key references users_profile(id) on delete cascade,
  balance_available int not null default 0, -- CLP
  balance_held int not null default 0,      -- CLP retenido
  updated_at timestamptz not null default now()
);

create table if not exists rides (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references users_profile(id),
  university_id uuid not null references universities(id),
  campus_id uuid not null references campuses(id),
  origin_commune text not null check (origin_commune in ('Chicureo','Lo Barnechea','Providencia','Vitacura','La Reina','Buin')),
  direction ride_direction not null,
  departure_at timestamptz not null,
  seat_price int not null default 2000,
  seats_total int not null check (seats_total > 0),
  seats_available int not null check (seats_available >= 0),
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references rides(id) on delete cascade,
  passenger_id uuid not null references users_profile(id),
  amount_total int not null default 2000,
  status booking_status not null default 'reserved',
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (ride_id, passenger_id)
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users_profile(id),
  booking_id uuid references bookings(id),
  type tx_type not null,
  amount int not null, -- positivo/negativo según tipo
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists withdrawals (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references users_profile(id),
  amount int not null check (amount >= 20000),
  status text not null default 'requested',
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists strikes (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references users_profile(id),
  reason text not null,
  booking_id uuid references bookings(id),
  created_at timestamptz not null default now()
);
```

---

### 3) RLS policies (mínimas y seguras)

```sql
alter table users_profile enable row level security;
alter table wallets enable row level security;
alter table rides enable row level security;
alter table bookings enable row level security;
alter table transactions enable row level security;
alter table withdrawals enable row level security;
alter table strikes enable row level security;

create policy "profile_self_rw" on users_profile
for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "wallet_self_read" on wallets
for select using (auth.uid() = user_id);

create policy "rides_public_read" on rides
for select using (true);

create policy "rides_driver_insert" on rides
for insert with check (auth.uid() = driver_id);

create policy "rides_driver_update" on rides
for update using (auth.uid() = driver_id);

create policy "bookings_self_read" on bookings
for select using (
  auth.uid() = passenger_id or
  exists(select 1 from rides r where r.id = ride_id and r.driver_id = auth.uid())
);

create policy "bookings_passenger_insert" on bookings
for insert with check (auth.uid() = passenger_id);

create policy "tx_self_read" on transactions
for select using (auth.uid() = user_id);

create policy "withdrawals_driver_rw" on withdrawals
for all using (auth.uid() = driver_id) with check (auth.uid() = driver_id);

create policy "strikes_driver_read" on strikes
for select using (auth.uid() = driver_id);
```

---

### 4) Funciones Supabase (RPC) críticas

```sql
create or replace function public.create_booking(p_ride_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  v_user uuid := auth.uid();
  v_booking_id uuid;
  v_price int;
begin
  if v_user is null then raise exception 'unauthorized'; end if;

  select seat_price into v_price from rides
  where id = p_ride_id and status='active' and seats_available > 0
  for update;

  if v_price is null then raise exception 'ride unavailable'; end if;

  update wallets set balance_available = balance_available - v_price,
                    balance_held = balance_held + v_price,
                    updated_at = now()
  where user_id = v_user and balance_available >= v_price;

  if not found then raise exception 'insufficient balance'; end if;

  update rides set seats_available = seats_available - 1 where id = p_ride_id;

  insert into bookings(ride_id, passenger_id, amount_total)
  values (p_ride_id, v_user, v_price)
  returning id into v_booking_id;

  insert into transactions(user_id, booking_id, type, amount, metadata)
  values (v_user, v_booking_id, 'booking_hold', -v_price, '{}'::jsonb);

  return v_booking_id;
end $$;

create or replace function public.confirm_boarding(p_booking_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_passenger uuid;
  v_driver uuid;
  v_amount int;
begin
  select b.passenger_id, r.driver_id, b.amount_total
    into v_passenger, v_driver, v_amount
  from bookings b join rides r on r.id=b.ride_id
  where b.id = p_booking_id and b.status='reserved'
  for update;

  if auth.uid() is distinct from v_passenger then raise exception 'forbidden'; end if;

  update wallets set balance_held = balance_held - v_amount where user_id = v_passenger;
  update wallets set balance_available = balance_available + v_amount where user_id = v_driver;

  update bookings set status='completed', confirmed_at=now() where id=p_booking_id;

  insert into transactions(user_id, booking_id, type, amount) values
    (v_passenger, p_booking_id, 'release_to_driver', 0),
    (v_driver, p_booking_id, 'release_to_driver', v_amount);
end $$;
```

---

### 5) Estructura Flutter PWA (simple)

```txt
/lib
  /app
    app.dart
    router.dart
    theme.dart
  /core
    supabase_client.dart
    constants.dart
  /features/auth
  /features/profile_switch
  /features/rides_publish
  /features/rides_search
  /features/booking
  /features/wallet
  /features/transactions
  /shared/widgets
  main.dart
```

---

### 6) Modelos Flutter (ejemplo)

```dart
class Ride {
  final String id;
  final String driverId;
  final String universityId;
  final String campusId;
  final String originCommune;
  final String direction; // to_campus|from_campus
  final DateTime departureAt;
  final int seatPrice;
  final int seatsAvailable;
  // fromJson/toJson...
}
```

---

### 7) API service layer (Supabase)

- `AuthService`: signIn/signUp/signOut.
- `ProfileService`: getProfile(), setRoleMode().
- `RideService`: createRide(), searchRides(filters).
- `BookingService`: createBookingRPC(), confirmBoardingRPC().
- `WalletService`: getWallet(), getTransactions(), createTopupIntent().
- `WithdrawalService`: requestWithdrawal().

---

### 8) Pantallas MVP

- Login
- Home con switch Conductor/Pasajero
- Publicar turno (ida/vuelta, comuna, campus, hora, cupos)
- Buscar turnos (filtros rápidos + lista)
- Reserva (resumen + confirmar)
- Wallet (saldo, recargar, historial)
- Mis viajes (botón “ME SUBÍ AL AUTO” en reserva activa)

---

### 9) Integración de pagos (Mercado Pago)

1. App solicita `createTopupIntent(amount)` a Edge Function.
2. Edge Function crea preferencia en MP y retorna `init_point`.
3. Usuario paga en MP checkout.
4. Webhook MP verifica pago aprobado.
5. Webhook ejecuta SQL: suma `wallets.balance_available` + inserta `transactions(type='topup')`.
6. App refresca saldo.

---

### 10) Seguridad (mínimo viable serio)

- RLS en todas las tablas sensibles.
- RPC `security definer` + validaciones `auth.uid()`.
- Idempotencia en webhook de Mercado Pago (guardar `external_payment_id` único).
- Rate limit en Edge Functions.
- Auditoría por `transactions` inmutable (solo insert).

---

### 11) Escalabilidad barata

- Empezar en plan free/pro de Supabase y escalar verticalmente.
- Evitar microservicios al inicio: monolito serverless con SQL RPC.
- Índices en `rides(departure_at, campus_id, direction)` y `bookings(ride_id, passenger_id)`.
- Notificaciones push por lotes/cron, no en tiempo real continuo.
- Retiros quincenales manuales al inicio (evita costos de payouts automáticos).
- Feature flags para activar comisiones/penalidades sin migraciones grandes.