# TurnoApp - Diagnostico DB y conectividad

Este documento te permite validar rapidamente por que falla la carga de
universidades/campus y dejar la app funcional de extremo a extremo.

## 1) Verificacion minima en Supabase SQL Editor

Ejecuta este bloque completo:

```sql
-- A. Datos seed
select count(*) as universities_count from public.universities;
select count(*) as campuses_count from public.campuses;

-- B. Permisos y RLS para tablas de referencia
grant select on table public.universities to anon, authenticated;
grant select on table public.campuses to anon, authenticated;

alter table public.universities enable row level security;
drop policy if exists "universities_public_read" on public.universities;
create policy "universities_public_read"
  on public.universities
  for select
  using (true);

alter table public.campuses enable row level security;
drop policy if exists "campuses_public_read" on public.campuses;
create policy "campuses_public_read"
  on public.campuses
  for select
  using (true);

-- C. Comprobacion final
select id, code, name from public.universities order by name;
```

Resultado esperado:
- universities_count >= 5
- campuses_count >= 14
- select final retorna filas.

## 2) Verificacion de migraciones

Si usas CLI local:

```bash
supabase link --project-ref TU_PROJECT_ID
supabase db push
```

Debe aplicar hasta:
- `00000000000008_reference_diag.sql`

## 3) Verificacion de variables en Flutter (obligatorio)

Ejecuta la app pasando URL y ANON key reales:

```bash
flutter run -d edge \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Si falta alguna variable, la app ahora muestra una pantalla de
"Configuracion incompleta" al iniciar.

## 4) Verificacion de Edge Functions

En Supabase Dashboard -> Settings -> Edge Functions -> Secrets:
- `MP_ACCESS_TOKEN`
- `APP_BASE_URL`
- `MP_WEBHOOK_SECRET`

Luego desplegar:

```bash
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

## 5) Diagrama de funcionamiento (runtime)

```text
Flutter PWA
  -> Supabase Auth (signup/login)
  -> PostgREST (universities/campuses, rides, bookings, wallets)
  -> RPC SQL (create_booking, confirm_boarding, cancel_booking)
  -> Edge create-topup-intent
      -> Mercado Pago
      -> webhook mercadopago-webhook
          -> RPC credit_wallet_topup
```

## 6) Notas sobre el frontend actual

- La app ahora tiene fallback local para referencias:
  - universidades y campus cargan aun si Supabase falla.
- El problema de conectividad sigue visible como banner para que no pase
  desapercibido en QA.
- Registro ya no revienta por upserts post-signup; el trigger DB sigue siendo
  la fuente principal para perfil + wallet.
