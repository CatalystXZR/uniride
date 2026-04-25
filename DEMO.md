# TurnoApp - Demo Accounts

## Credenciales de Prueba para TestFlight

| Tipo | Email | Password |
|------|-------|----------|
| Pasajero | `pasajero@demo.com` | `demo1234` |
| Conductor | `conductor@demo.com` | `demo1234` |

## Configuración inicial

### SQL para Supabase (ejecutar en SQL Editor):

```sql
-- ==========================================
-- CREAR CUENTAS DEMO PARA TESTFLIGHT
-- ==========================================

-- 1) Cuenta demo PASAJERO
insert into auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
values (
  'pasajero@demo.com',
  crypt('demo1234', gen_salt('bf')),
  now(),
  '{"full_name": "Demo Pasajero", "accepted_terms": true, "role_mode": "passenger"}'
)
on conflict (email) do nothing;

-- 2) Cuenta demo CONDUCTOR  
insert into auth.users (email, encrypted_password, email_confirmed_at, raw_user_meta_data)
values (
  'conductor@demo.com',
  crypt('demo1234', gen_salt('bf')),
  now(),
  '{"full_name": "Demo Conductor", "accepted_terms": true, "role_mode": "driver", "has_valid_license": true, "vehicle_brand": "Toyota", "vehicle_model": "Yaris", "vehicle_plate": "ABC123"}'
)
on conflict (email) do nothing;

-- 3) CARGAR $50,000 A CADA CUENTA
select public.credit_wallet_topup(
  (select id from auth.users where email = 'pasajero@demo.com'),
  50000,
  'demo-topup-pasajero',
  50000,
  0,
  'demo'
);

select public.credit_wallet_topup(
  (select id from auth.users where email = 'conductor@demo.com'),
  50000,
  'demo-topup-conductor', 
  50000,
  0,
  'demo'
);
```

## Flujo de prueba recomendado

1. **Login como Pasajero** (`pasajero@demo.com`)
   - Buscar turno disponible
   - Reservar asiento
   - Ver en "Mis reservas"

2. **Login como Conductor** (`conductor@demo.com`)
   - Publicar turno
   - Aceptar pasajero
   - Gestionar viaje

## Notas

- Ambas cuentas tienen $50.000 CLP de saldo
- La cuenta conductor tiene vehículo registrado (Toyota Yaris, patente ABC123)
- Los términos están aceptados automáticamente
