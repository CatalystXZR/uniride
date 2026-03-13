# TurnoApp — Guía de despliegue

Sigue estos pasos en orden. Tiempo estimado para el primer deploy: ~45 minutos.

---

## Requisitos previos

| Herramienta | Versión | Instalación |
|---|---|---|
| Flutter | 3.29+ | https://docs.flutter.dev/get-started/install |
| Supabase CLI | 1.x | `npm i -g supabase` o `brew install supabase/tap/supabase` |
| Vercel CLI | latest | `npm i -g vercel` |
| Node.js | 18+ | https://nodejs.org |
| Cuenta Mercado Pago developer | — | https://www.mercadopago.cl/developers |

---

## 1. Crear proyecto Supabase

1. Ir a https://supabase.com → **New project**.
2. Elegir región cercana a Chile: **South America East — São Paulo**.
3. Guardar la **database password** generada.
4. Esperar ~2 minutos a que termine el provisionamiento.

---

## 2. Obtener credenciales

En **Supabase Dashboard → Settings → API**:

| Variable | Dónde encontrarla |
|---|---|
| `SUPABASE_URL` | "Project URL" |
| `SUPABASE_ANON_KEY` | clave "anon / public" |
| `SUPABASE_SERVICE_ROLE_KEY` | clave "service_role / secret" — **nunca exponer en la app** |

Copiar `.env.example` a `.env` y completar los valores.

---

## 3. Correr migraciones de base de datos

```bash
supabase login
supabase link --project-ref TU_PROJECT_ID   # el ID está en la URL: app.supabase.com/project/TU_PROJECT_ID
supabase db push
```

Esto ejecuta todos los archivos en `supabase/migrations/` en orden:

| # | Archivo | Qué crea |
|---|---|---|
| 00 | `_schema.sql` | 9 tablas, enums, índices |
| 01 | `_rls.sql` | Políticas Row Level Security |
| 02 | `_functions.sql` | RPCs: `create_booking`, `confirm_boarding`, `cancel_booking` |
| 03 | `_auth_trigger.sql` | Trigger: crea perfil + billetera al registrarse |
| 04 | `_seed.sql` | 5 universidades y 14 campus con UUIDs fijos |
| 05 | `_webhook_rpc.sql` | RPC `credit_wallet_topup` |
| 06 | `_public_grants.sql` | `GRANT SELECT` en tablas públicas al rol `anon` |
| 07 | `_reference_rls.sql` | RLS + política pública en `universities` y `campuses` |

Verificar en **Supabase Dashboard → Table Editor** que existen las tablas y que `universities` tiene 5 filas.

---

## 4. Desplegar Edge Functions

### 4a. Configurar variables de entorno

En **Supabase Dashboard → Settings → Edge Functions → Secrets**, agregar:

| Clave | Valor |
|---|---|
| `MP_ACCESS_TOKEN` | Access token de Mercado Pago (`APP_USR-...`) |
| `APP_BASE_URL` | URL pública de la app, ej: `https://turnoapp.vercel.app` |
| `MP_WEBHOOK_SECRET` | Secret del webhook de MP (ver paso 5) |

> `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son inyectadas automáticamente — **no agregarlas manualmente**.

### 4b. Desplegar funciones

```bash
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

Las URLs desplegadas siguen este patrón:
```
https://TU_PROJECT_ID.supabase.co/functions/v1/create-topup-intent
https://TU_PROJECT_ID.supabase.co/functions/v1/mercadopago-webhook
```

---

## 5. Configurar webhooks de Mercado Pago

1. Ir a https://www.mercadopago.cl/developers/panel/app → tu app → **Webhooks**.
2. Agregar URL:
   ```
   https://TU_PROJECT_ID.supabase.co/functions/v1/mercadopago-webhook
   ```
3. Seleccionar tipo de evento: **Pagos** (`payment`).
4. Copiar el **Webhook Secret** que provee MP y guardarlo como `MP_WEBHOOK_SECRET` en los secrets de Edge Functions (paso 4a).

> La `notification_url` en `create-topup-intent/index.ts` se deriva automáticamente de `SUPABASE_URL`, por lo que **no requiere cambios manuales**.

---

## 6. Build de la Flutter PWA

```bash
cd turnoapp
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=https://TU_PROJECT_ID.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

El output queda en `turnoapp/build/web/`.

---

## 7. Deploy en Vercel (configuración actual)

La app está actualmente desplegada en Vercel. Vercel sirve contenido estático correctamente, pero requiere una configuración adicional para que el enrutamiento SPA funcione (todas las rutas deben devolver `index.html`).

### 7a. Primer deploy manual

```bash
cd turnoapp/build/web
vercel --prod
```

Vercel detectará que es un sitio estático. Cuando pregunte por el directorio de output, confirmar que es el directorio actual (`.`).

### 7b. Configurar SPA fallback (obligatorio)

Sin esta configuración, las rutas como `/search` o `/booking/123` devolverán 404 si el usuario refresca la página o entra directamente por URL.

Crear el archivo `turnoapp/build/web/vercel.json` **antes** de hacer deploy, o mejor aún, crearlo en la raíz del proyecto para que persista entre builds:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

> **Importante:** Este archivo se sobreescribe cada vez que se hace `flutter build web`. La solución es copiarlo automáticamente después del build:
> ```bash
> flutter build web --release \
>   --dart-define=SUPABASE_URL=... \
>   --dart-define=SUPABASE_ANON_KEY=... \
> && cp vercel.json turnoapp/build/web/vercel.json
> ```
> O mantener un `vercel.json` en la raíz del repositorio y configurar Vercel para usarlo.

### 7c. Redeploy después de cada build

```bash
cd turnoapp/build/web
vercel --prod
```

### 7d. Vincular proyecto Vercel (para deploys repetidos)

Si ya existe el proyecto en Vercel, vincularlo localmente para no tener que confirmar configuración cada vez:

```bash
cd turnoapp/build/web
vercel link   # seleccionar el proyecto existente
vercel --prod # deploys directos sin confirmaciones
```

### 7e. Variables de entorno en Vercel

Las variables `SUPABASE_URL` y `SUPABASE_ANON_KEY` se inyectan en tiempo de **build** mediante `--dart-define`, no en tiempo de ejecución, por lo que **no es necesario configurarlas en el Dashboard de Vercel**. El HTML y JS generados ya las tienen embebidas.

---

## 8. Restringir CORS (hardening antes de producción real)

En `supabase/functions/create-topup-intent/index.ts` y `mercadopago-webhook/index.ts`, los `corsHeaders` actualmente permiten `*`. Antes de abrir la app al público general, restringir al dominio real:

```ts
"Access-Control-Allow-Origin": "https://turnoapp.vercel.app",
```

Luego redesplegar ambas funciones:
```bash
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
```

---

## 9. Smoke test

1. Registrar cuenta nueva → verificar que se crearon filas en `users_profile` y `wallets` (Supabase Table Editor).
2. Recargar billetera con una **tarjeta de prueba de MP** → confirmar que el saldo se actualiza.
3. Publicar un viaje como Conductor.
4. Reservar el viaje como Pasajero → confirmar que el saldo queda retenido (`balance_held`).
5. Presionar "ME SUBÍ AL AUTO" → confirmar que los fondos pasan al conductor.
6. Revisar tabla `transactions` para verificar el registro de cada movimiento.

---

## 10. Workflow de iteración (ciclo de feedback)

Este es el proceso para incorporar cambios después de recibir feedback de los testers:

```
1. Recibir feedback de socios/testers
2. Identificar qué archivos afecta cada cambio
3. Modificar código en turnoapp/lib/ y/o supabase/
4. Si hay cambios en DB → crear nueva migración en supabase/migrations/
5. Aplicar migración: supabase db push
6. Si hay cambios en Edge Functions → redesplegar: supabase functions deploy <nombre>
7. Hacer nuevo build: flutter build web --release --dart-define=...
8. Copiar vercel.json al directorio de build
9. Redesplegar: cd turnoapp/build/web && vercel --prod
10. Verificar en producción
```

### Tipos de cambio y qué tocar

| Tipo de cambio | Archivos a modificar |
|---|---|
| UI / pantalla nueva | `turnoapp/lib/features/` + ruta en `router.dart` |
| Lógica de negocio nueva | `turnoapp/lib/services/` + posiblemente nueva RPC en Supabase |
| Nuevo campo en DB | Nueva migración `supabase/migrations/0X_...sql` |
| Cambio en pagos MP | `supabase/functions/create-topup-intent/index.ts` + redeploy |
| Nuevo precio / comuna | `turnoapp/lib/core/constants.dart` + migración si afecta el `CHECK` de la DB |
| Corrección de bug visual | Solo el archivo de la pantalla correspondiente en `features/` |

### Cómo reportar un bug a la IA

Para que la IA pueda resolver cualquier problema eficientemente, incluir siempre:

1. **Descripción exacta** de qué falla (texto del error si hay, o descripción del comportamiento incorrecto)
2. **Pantalla donde ocurre** (registro, búsqueda, reserva, billetera, etc.)
3. **Pasos para reproducirlo** (qué hizo el usuario antes de que fallara)
4. **Si es en DB**, ejecutar en el SQL Editor de Supabase y adjuntar resultado:
   ```sql
   -- Verificar estado de tablas relevantes
   SELECT * FROM rides WHERE status = 'active' LIMIT 5;
   SELECT * FROM bookings ORDER BY created_at DESC LIMIT 5;
   SELECT * FROM wallets WHERE user_id = 'UUID_DEL_USUARIO';
   ```
5. **Adjuntar `CONTEXTO_IA.md`** al inicio del mensaje para que la IA tenga el contexto completo del proyecto.

---

## Resumen de variables de entorno

| Variable | Usada en | Requerida |
|---|---|---|
| `SUPABASE_URL` | Flutter (dart-define) + Edge Functions (auto) | Sí |
| `SUPABASE_ANON_KEY` | Flutter (dart-define) | Sí |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions (auto-inyectada) | Sí (automática) |
| `MP_ACCESS_TOKEN` | Edge Function `create-topup-intent` | Sí |
| `APP_BASE_URL` | Edge Function `create-topup-intent` | Sí |
| `MP_WEBHOOK_SECRET` | Edge Function `mercadopago-webhook` | Recomendado |

---

## Troubleshooting

**`supabase db push` falla con error de permisos**
→ Verificar que se ejecutó `supabase link --project-ref TU_PROJECT_ID` primero.

**Edge Function devuelve 401**
→ Verificar que la app Flutter envía el header `Authorization: Bearer <token>`. Confirmar que `SUPABASE_URL` y `SUPABASE_ANON_KEY` son correctos en el build.

**Dropdown de universidades vacío en el registro**
→ Ejecutar la migración `07_reference_rls.sql` en el SQL Editor de Supabase. Si ya se ejecutó, revisar la consola del navegador (F12) para ver el error real — ahora la app lo muestra con un botón "Reintentar".

**Webhook de MP no se dispara**
→ Confirmar que la URL en el dashboard de MP apunta a la Edge Function de Supabase (no a `APP_BASE_URL`). Revisar logs en Supabase Dashboard → Edge Functions → Logs.

**Saldo no se actualiza después de un pago MP**
→ Revisar tabla `mp_payments` por si el pago ya fue procesado (idempotencia). Revisar logs de la Edge Function. Verificar que `MP_ACCESS_TOKEN` es el token de producción si se está en producción.

**Rutas devuelven 404 en Vercel al refrescar**
→ Asegurarse de que `vercel.json` con el rewrite `"/(.*)" → "/index.html"` está en el directorio `turnoapp/build/web/` antes de hacer deploy.

**Build de Flutter falla**
→ Verificar que se ejecutó `flutter pub get` primero. Confirmar que la versión de Flutter es 3.29+. Revisar que no haya errores de compilación con `flutter analyze`.
