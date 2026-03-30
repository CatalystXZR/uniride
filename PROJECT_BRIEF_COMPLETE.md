# TurnoApp - Documento Maestro de Proyecto

Este documento sirve como fuente unica y actualizada para entender TurnoApp en dos niveles:

1. **Nivel IA/tecnico**: arquitectura, decisiones, flujo de datos, seguridad, deployment y puntos de extension.
2. **Nivel negocio/usuario**: que problema resuelve, como funciona la app, por que se tomaron ciertas decisiones.

---

## 1) Resumen ejecutivo

TurnoApp es una plataforma de carpooling universitario en Chile para coordinar viajes entre estudiantes conductores y pasajeros.

- **Objetivo principal**: reducir costo y friccion de traslado a campus, con foco en seguridad y trazabilidad financiera.
- **Modelo actual**: PWA (web mobile-first), backend serverless y pagos integrados con Mercado Pago.
- **Estado**: MVP avanzado / pre-Beta, con refactor en curso hacia mayor escalabilidad.

---

## 2) Problema que resuelve

### Dolor actual del usuario
- Traslados universitarios caros e ineficientes.
- Falta de coordinacion segura y estructurada entre estudiantes.
- Riesgo de pagos informales sin trazabilidad.

### Solucion propuesta
- Un flujo digital claro: **publicar turno -> reservar -> retener pago -> confirmar abordaje -> liberar pago**.
- Reglas de seguridad operativa: terminos, licencia declarada, no-show, strikes y suspension.
- Registro financiero auditable via ledger de transacciones.

---

## 3) Arquitectura de software

## Tipo de arquitectura
- **Frontend**: arquitectura modular por features en Flutter (PWA).
- **Estado**: enfoque mixto en transicion, con Riverpod incorporado en flujos criticos.
- **Backend**: serverless sobre Supabase (Postgres + Auth + RLS + RPC + Edge Functions).
- **Patron de dominio**: logica critica y financiera en base de datos (SQL-first + funciones RPC atomicas).

## Estilo general
- **Cliente liviano + backend fuerte** para asegurar consistencia de negocio.
- **Security by default** con RLS y funciones `SECURITY DEFINER` para operaciones sensibles.

---

## 4) Stack tecnologico y motivos

## Frontend
- **Flutter Web (Dart)**
  - Motivo: una sola base de codigo UI, buen time-to-market para PWA, soporte mobile-first.
- **go_router**
  - Motivo: enrutamiento declarativo con guards de autenticacion.
- **Riverpod**
  - Motivo: estado mas escalable y testeable que `setState` para dominios compartidos.
- **intl**
  - Motivo: formateo local (es_CL) de fechas y moneda.

## Backend
- **Supabase (PostgreSQL + Auth + Storage + Edge Functions)**
  - Motivo: stack administrado, rapido para producto temprano, SQL robusto para reglas de negocio.
- **RPC SQL (plpgsql)**
  - Motivo: transacciones atomicas para flujos financieros y de cupos.
- **Edge Functions (Deno + TypeScript)**
  - Motivo: integraciones externas seguras (Mercado Pago webhook/preference).

## Pagos
- **Mercado Pago Checkout Pro**
  - Motivo: cobertura regional y webhook oficial para conciliacion de pagos.

## Deploy
- **Vercel** para frontend.
- **Supabase Cloud** para backend.

---

## 5) Lenguajes utilizados y razones

- **Dart** (app Flutter): velocidad de desarrollo UI y mantenimiento unificado.
- **SQL / PLpgSQL** (negocio critico): atomicidad, integridad, performance en operaciones financieras.
- **TypeScript** (Edge Functions): tipado para integraciones API externas y menor riesgo de errores en runtime.
- **YAML** (CI/CD): pipeline de validacion/deploy automatizado.

---

## 6) Nodos/componentes del sistema

## Nodo A - Cliente (Flutter PWA)
- Renderiza UI, captura intencion de usuario y llama servicios.
- No decide reglas financieras finales.

## Nodo B - Supabase Auth
- Gestiona identidad y sesion JWT.
- Dispara trigger de bootstrap de perfil/billetera al registrar usuario.

## Nodo C - API PostgREST + RPC
- Expone CRUD y funciones RPC.
- RLS limita acceso por usuario/rol.

## Nodo D - PostgreSQL
- Fuente unica de verdad.
- Ejecuta constraints, triggers, indices, funciones atomicas y ledger.

## Nodo E - Edge Functions
- `create-topup-intent`: crea preferencia de pago en MP.
- `mercadopago-webhook`: valida firma HMAC, consulta pago y acredita wallet de forma idempotente.

## Nodo F - Mercado Pago
- Procesa pago del usuario final y notifica webhook.

---

## 7) Flujo funcional completo (end-to-end)

## 7.1 Registro
1. Usuario crea cuenta (email/password).
2. Trigger DB crea `users_profile` y `wallet`.
3. Usuario queda listo para modo pasajero.

## 7.2 Activacion modo conductor
1. Usuario acepta terminos y declara licencia vigente.
2. Completa datos de vehiculo.
3. Si no esta suspendido, puede publicar turnos.

## 7.3 Publicar turno
1. Conductor define origen, campus, direccion, horario, cupos y punto de encuentro.
2. Trigger/DB ajusta precio y comision segun reglas.
3. Turno queda visible para busqueda.

## 7.4 Reservar turno
1. Pasajero busca y reserva.
2. RPC `create_booking` valida disponibilidad y saldo.
3. DB retiene fondos (`available -> held`) y descuenta cupo de forma atomica.

## 7.5 Confirmar abordaje
1. Pasajero pulsa "ME SUBI AL AUTO".
2. RPC `confirm_boarding` libera pago al conductor.
3. Ledger registra movimientos y fee.

## 7.6 Cancelaciones y no-show
- Cancelacion pasajero: refund inmediato.
- Cancelacion conductor: refund a pasajeros + posible strike.
- No-show reportado por pasajero: refund + evaluacion de strike.

## 7.7 Recarga billetera
1. Cliente pide intent de recarga.
2. Edge crea preference en MP.
3. MP notifica webhook.
4. Webhook valida firma e idempotencia.
5. RPC acredita wallet.

---

## 8) Arquitectura de datos (alto nivel)

## Tablas principales
- `users_profile`
- `wallets`
- `rides`
- `bookings`
- `transactions`
- `mp_payments`
- `withdrawals`
- `strikes`
- `universities`
- `campuses`

## Principios de datos
- Ledger inmutable para auditoria (`transactions`).
- RLS en tablas sensibles.
- Indices en rutas de consulta frecuentes.
- Migraciones versionadas en `supabase/migrations/`.

---

## 9) Seguridad y cumplimiento

## Controles implementados
- Row Level Security por usuario/rol.
- Operaciones monetarias en RPC atomicas con `SECURITY DEFINER`.
- Verificacion HMAC en webhook de Mercado Pago.
- Idempotencia para evitar doble acreditacion.
- Reglas de suspension por strikes.

## Riesgos conocidos (gestionados)
- Falta suite de tests amplia (actualmente smoke + analyze + build).
- Todavia hay partes del frontend con `setState` (migracion progresiva).
- Fallback local de referencias puede ocultar fallas de acceso en QA.

---

## 10) Frontend: estructura y experiencia de usuario

## Estructura por features
- `auth`: login/registro.
- `profile_switch`: home y cambio de modo.
- `rides_publish`: publicacion de turnos.
- `rides_search`: busqueda con filtros.
- `booking`: detalle y reserva.
- `wallet`: saldo, recarga y retiro.
- `my_rides`: reservas pasajero y turnos conductor.
- `legal`: terminos/seguridad.

## Enrutamiento
- Router central con guard de autenticacion (`go_router`).
- Rutas clave: `/login`, `/register`, `/home`, `/publish`, `/search`, `/booking/:rideId`, `/wallet`, `/my-rides`, `/driver-rides`, `/terms`, `/profile/edit`.

## Estado
- Riverpod ya integrado en dominios criticos (`wallet`, `search`, `my_rides`, `driver_rides`).
- Resto del sistema en migracion incremental para no romper flujos activos.

---

## 11) Backend: integraciones y jobs criticos

## Edge Function: create-topup-intent
- Autentica usuario via JWT.
- Valida monto minimo/maximo.
- Crea preferencia MP y retorna `init_point`.

## Edge Function: mercadopago-webhook
- Recibe evento pago.
- Verifica firma HMAC.
- Consulta estado de pago en MP.
- Si aprobado, acredita wallet via RPC.
- Evita duplicados por `external_payment_id`.

---

## 12) CI/CD y despliegue

## Pipeline GitHub Actions
Archivo: `.github/workflows/vercel-deploy.yml`

Pasos:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test` (si existe carpeta `test`)
4. `flutter build web --release` con `SUPABASE_URL` y `SUPABASE_ANON_KEY`
5. Deploy a Vercel en `--prod`

## Variables necesarias
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

---

## 13) Estado actual del proyecto (foto tecnica)

- App funcional en produccion web (PWA).
- Despliegue Vercel operativo.
- Migraciones DB actualizadas hasta `00000000000012_beta_observability_scalability.sql`.
- CI reforzado con analisis y gates basicos.
- Refactor de estado iniciado y aplicado en flujos core.

---

## 14) Motivos de decisiones arquitectonicas clave

- **SQL-first en negocio critico**: reduce inconsistencias entre clientes y protege integridad financiera.
- **RLS + RPC**: combina seguridad por fila con operaciones atomicas centralizadas.
- **PWA primero**: salida rapida al mercado sin costo de doble desarrollo nativo.
- **Riverpod incremental**: mejora escalabilidad sin reescritura total de golpe.
- **Mercado Pago + webhook**: conciliacion real de pagos y trazabilidad.

---

## 15) Como explicar TurnoApp a una persona no tecnica

TurnoApp es una app para compartir viaje entre estudiantes.

- Si eres pasajero, buscas un turno y reservas.
- Si eres conductor, publicas tu ruta y cupos.
- El pago no se libera altiro: queda retenido hasta que confirmas que te subiste.
- Si algo falla (cancelaciones/no-show), hay reglas y reembolsos claros.
- Todo queda registrado para evitar fraudes y conflictos.

En simple: es una forma segura y ordenada de coordinar carpool universitario.

---

## 16) Como usar este documento

## Para IA
- Leer completo antes de modificar codigo.
- Validar que cambios respeten flujo financiero atomico y RLS.
- Revisar docs complementarios: `START_HERE_IA.md`, `PLAN_BETA_ESCALABLE.md`, `RUNBOOK_5MIN.md`.

## Para equipo humano
- Usarlo como base de presentacion del proyecto.
- Referenciar secciones 1, 2, 3, 7 y 15 para explicar producto y arquitectura.
- Referenciar secciones 9, 11 y 12 para auditoria y operacion.

---

## 17) Glosario rapido

- **PWA**: aplicacion web que se comporta como app movil.
- **RLS**: reglas de seguridad a nivel fila en base de datos.
- **RPC**: funcion remota ejecutada en DB.
- **Idempotencia**: procesar varias veces un mismo evento sin duplicar efecto.
- **Ledger**: registro contable de movimientos.

---

## 18) Referencias de archivos clave

- App bootstrap: `turnoapp/lib/main.dart`
- Router: `turnoapp/lib/app/router.dart`
- Tema visual: `turnoapp/lib/app/theme.dart`
- Config Supabase: `turnoapp/lib/core/supabase_client.dart`
- Providers estado: `turnoapp/lib/providers/`
- Edge topup: `supabase/functions/create-topup-intent/index.ts`
- Edge webhook: `supabase/functions/mercadopago-webhook/index.ts`
- CI deploy: `.github/workflows/vercel-deploy.yml`
- Plan beta: `PLAN_BETA_ESCALABLE.md`

---

Documento generado y actualizado para contexto Linux/Fedora y estado actual del repositorio.
