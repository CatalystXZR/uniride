# PLAN MAESTRO BETA ESCALABLE - TurnoApp

Este plan consolida mejoras de frontend, backend, seguridad, operacion y UX para llevar TurnoApp desde MVP funcional a una Beta estable, usable y escalable.

## 1) Estado actual (diagnostico tecnico)

### Fortalezas
- Arquitectura serverless correcta para etapa MVP (Flutter Web + Supabase + Edge Functions).
- Seguridad base bien planteada: RLS, RPC `SECURITY DEFINER`, ledger de transacciones inmutable, webhook con HMAC e idempotencia.
- Reglas de negocio criticas implementadas (retencion/liberacion, no-show, strikes/suspension, recarga MP).
- Documentacion amplia para handoff y operacion.

### Riesgos tecnicos a corregir
- Estado en frontend acoplado a `setState` por pantalla: riesgo de inconsistencias (wallet, perfil, rides).
- Sin capa uniforme de errores/reintentos en cliente.
- Falta de tests automatizados robustos y calidad en CI antes de deploy.
- Documentacion operativa con comandos de Windows mezclados con entorno actual Linux/Fedora.
- Falta de observabilidad y alertas operativas (metricas de negocio y fallos de funciones).

## 2) Objetivo Beta

Construir una Beta con estos atributos:
- Estabilidad operativa (fallo controlado, sin corrupcion de datos).
- UX clara, fluida y consistente en mobile-first.
- Escalabilidad incremental sin reescritura total.
- Seguridad y auditoria listas para trafico real inicial.
- Proceso de release repetible y confiable en Linux.

## 3) Arquitectura objetivo

## Frontend (Flutter)
- Estado global con Riverpod (sin romper servicios actuales en primera etapa).
- Capa de presentacion por feature + `AsyncValue` estandar para carga/error/empty/success.
- Design system minimo: tokens de color/espaciado/tipografia/radios/sombras.
- Navegacion con guards centralizados y rutas desacopladas de widgets pesados.

## Backend (Supabase)
- Continuar con SQL-first en RPC para operaciones financieras atomicas.
- Estrategia de migraciones tipo expand-contract (sin downtime).
- Refuerzo de constraints e indices para volumen Beta.
- Edge Functions con validaciones consistentes, logs estructurados y manejo de errores uniforme.

## Operacion
- CI con gates obligatorios (`flutter analyze`, tests, build, chequeo SQL lint basico).
- Runbooks Linux/Fedora como fuente unica de verdad.
- Monitoreo de fallos de pagos, webhook, y RPC financieras.

## 4) Plan de trabajo por fases

## Fase 0 - Baseline seguro (1-2 dias)
Objetivo: congelar linea base y evitar regresiones.

### Tareas
- Establecer versionado de dependencias y lock controlado.
- Agregar pipeline CI minimo:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release`
- Crear smoke test scriptable de rutas criticas.
- Definir checklist de rollback operativo.

### Criterio de salida
- Build y checks pasan en CI para cada PR.
- Cualquier fallo bloquea merge a `main`.

## Fase 1 - Refactor de estado (Riverpod) sin ruptura (3-5 dias)
Objetivo: eliminar dependencia de `setState` como estado principal.

### Tareas
- Agregar `flutter_riverpod`.
- Crear providers por dominio:
  - `auth_provider`
  - `profile_provider`
  - `wallet_provider`
  - `rides_provider`
  - `booking_provider`
  - `reference_data_provider`
- Mantener servicios actuales y envolverlos en providers (adaptador).
- Migrar pantallas de alto impacto:
  - Home
  - Wallet
  - Search Rides
  - My Rides (pasajero y conductor)

### Criterio de salida
- Mismas funcionalidades del MVP sin regresiones.
- Sin refrescos manuales inconsistentes entre pantallas.

## Fase 2 - UX/UI Beta y usabilidad (3-4 dias)
Objetivo: interfaz mas limpia, moderna y operable en mobile.

### Tareas
- Unificar tema en tokens:
  - paleta semantica (`success/warning/error/info`)
  - estados de componentes (hover/focus/disabled)
  - escalas de texto y espaciado
- Crear componentes reutilizables:
  - `AppScaffold`
  - `SectionCard`
  - `PrimaryButton`, `SecondaryButton`
  - `AsyncStateView`
- Mejorar microinteracciones sin sobrecargar:
  - skeleton en listas
  - transiciones suaves entre estados
  - feedback visual claro al reservar/cancelar/confirmar
- Accesibilidad:
  - contraste WCAG AA
  - tamanos de toque minimos
  - labels semanticos

### Criterio de salida
- UI consistente en mobile/desktop.
- Flujos criticos completables sin confusion.

## Fase 3 - Endurecimiento backend y datos (3-5 dias)
Objetivo: robustez para trafico Beta real.

### Tareas
- Revisar y fortalecer constraints:
  - validar definitivamente constraints `NOT VALID` pendientes.
  - normalizar validaciones de campos de conductor/vehiculo.
- Revisar indices y agregar parciales donde aplique:
  - rides activas por fecha/campus
  - bookings reservadas por ride
  - transacciones por usuario y tipo
- Agregar funciones de soporte operativo:
  - vista/materialized view de metricas diarias (reservas, cancelaciones, no-show, topups).
  - funcion de auditoria para conciliacion wallet/ledger.
- Endurecer Edge Functions:
  - validacion de payload uniforme
  - logs estructurados
  - timeouts y respuestas consistentes
  - politica de reintentos documentada

### Criterio de salida
- Integridad financiera verificable por queries de conciliacion.
- Rendimiento estable en consultas mas usadas.

## Fase 4 - Seguridad, compliance y confiabilidad (2-3 dias)
Objetivo: cerrar brechas de seguridad operativa.

### Tareas
- Revisar secretos y evitar defaults sensibles en cliente.
- Fortalecer controles de abuse/rate-limit en Edge Functions.
- Auditoria de RLS por tabla (tests de acceso anon/authenticated).
- Hardening de auth (confirmaciones y politicas segun entorno).
- Registro de eventos criticos:
  - login
  - topup creado
  - topup acreditado
  - booking hold/release/refund
  - strike emitido

### Criterio de salida
- Accesos no autorizados bloqueados y evidenciables.
- Eventos criticos trazables extremo a extremo.

## Fase 5 - QA, performance y Beta release (2-4 dias)
Objetivo: certificar estabilidad Beta.

### Tareas
- Test matrix:
  - smoke funcional completo
  - pruebas de regresion UI
  - pruebas de carga moderada en consultas de rides
- Performance frontend:
  - reducir re-renders
  - optimizar listas y parsing JSON
  - auditar bundle web y tiempos iniciales
- Estrategia de release gradual:
  - feature flags para cambios sensibles
  - monitoreo intensivo 48h post-release

### Criterio de salida
- Beta release checklist 100% verde.
- Plan de rollback probado.

## 5) Mala praxis detectada y solucion propuesta

1. Estado local disperso (`setState`) en flujos core.
   - Solucion: Riverpod por dominio + `AsyncValue`.

2. Manejo de errores heterogeneo.
   - Solucion: capa de errores tipados (`DomainException`) y mapper central.

3. Dependencia de fallback de referencias puede ocultar problemas de DB.
   - Solucion: modo QA sin fallback por flag y alertas visibles.

4. Documentacion operativa mezclada Windows/Linux.
   - Solucion: runbooks Linux/Fedora como default + seccion opcional Windows.

5. Calidad automatizada insuficiente previa a deploy.
   - Solucion: gates obligatorios en CI y bloqueo por fallos.

## 6) Estrategia de cambios sin romper produccion

- Usar ramas cortas por feature y PR pequenos.
- Cambios de DB por migraciones aditivas primero (expand).
- Despliegue de codigo que soporta ambos estados de schema.
- Migracion de datos y validacion.
- Retiro de estructura antigua al final (contract).

## 7) Plan de pruebas obligatorio

## Frontend
- `flutter analyze`
- `flutter test`
- smoke manual de:
  - registro/login
  - switch conductor/pasajero
  - publicar ride
  - buscar/reservar
  - confirmar abordaje
  - cancelar y no-show
  - wallet topup y retiro

## Backend
- `supabase db push` limpio
- pruebas SQL de:
  - integridad de pricing/fees
  - hold/release/refund
  - strike/suspension
  - idempotencia de webhook
- despliegue y prueba de Edge Functions con payload de prueba.

## 8) Operacion en Linux (Fedora) - comandos base

```bash
# Flutter
cd turnoapp
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Build
flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Supabase
cd ..
supabase login
supabase link --project-ref zawaevytpkvejhekyokw
supabase db push
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

## 9) Definicion de listo para Beta

- Sin errores de analisis ni tests fallidos.
- Flujos financieros core verificados sin inconsistencias.
- UI coherente y responsive en mobile/desktop.
- Observabilidad minima activa (errores y eventos de negocio).
- Documentacion actualizada para operacion Linux.

## 10) Entregables

- Refactor de estado en frontend (Riverpod).
- Mejoras visuales y de usabilidad en pantallas core.
- Migraciones backend de robustez e integridad.
- Edge functions endurecidas.
- Pipeline CI/CD reforzado.
- Runbooks/checklists actualizados para Linux.
