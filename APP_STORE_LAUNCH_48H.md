# TurnoApp - Plan App Store en 48h

Este documento es la guia de ejecucion para llegar a TestFlight/App Store en 2 dias con foco en cumplimiento, estabilidad y tiempos.

## 1) Estado actual

- Backend en Supabase con RLS y RPC atomicas.
- Frontend Flutter listo en web.
- Pagos con API preparada para provider switch (`PAYMENT_PROVIDER`), manteniendo fallback Mercado Pago.
- Comision por viaje actualizada a fija CLP 190.
- Recargas con fee 1% (monto cobrado > monto acreditado).
- Flujo in-app de eliminacion de cuenta agregado (requisito Apple para apps con account creation).

## 2) Requisitos Apple criticos (bloqueantes)

Segun App Review Guidelines y guias de Apple Developer:

1. App completa y funcional (sin placeholders, sin crashes)
2. Privacy Policy publica y accesible
3. App Privacy Details declarados correctamente en App Store Connect
4. Opcion de eliminacion de cuenta dentro de la app
5. Informacion de soporte/contacto visible
6. Backend disponible durante review + credenciales demo para App Review

## 3) Checklist tecnico antes de subir

## Backend
- [ ] `supabase db push` aplicado hasta migracion 14
- [ ] `create-topup-intent` desplegada
- [ ] `mercadopago-webhook` desplegada
- [ ] `create-stripe-topup-session` desplegada
- [ ] `stripe-webhook` desplegada
- [ ] `delete-account` desplegada
- [ ] Secrets configurados

Secrets minimos:
- `PAYMENT_PROVIDER=disabled` (modo seguro sin pasarela) o `mercadopago` para cobro real
- `MP_ACCESS_TOKEN`
- `MP_WEBHOOK_SECRET`
- `APP_BASE_URL`
- `STRIPE_PUBLISHABLE_KEY` (puede quedar seteada para preparar switch)
- `STRIPE_WEBHOOK_SECRET` (si se activa Stripe webhook)

## Frontend
- [ ] `flutter analyze` sin errores
- [ ] `flutter build web --release` OK
- [ ] Flujo de wallet muestra fee 1%
- [ ] Flujo de eliminar cuenta visible y funcional

## Operacion
- [ ] SQL de conciliacion wallet/ledger limpio
- [ ] Smoke test fin-a-fin completado

## 4) Smoke test obligatorio (fin-a-fin)

1. Registro/login
2. Publicar turno (verifica precio universidad + fee fijo 190)
3. Buscar/reservar
4. Confirmar abordaje (neto conductor + fee ledger)
5. Cancelaciones pasajero/conductor
6. No-show
7. Recarga wallet con 1% fee (cobro bruto, credito neto)
8. Solicitud retiro
9. Eliminar cuenta desde perfil
10. Flujo despacho: aceptar -> en camino -> llego -> abordar -> iniciar -> finalizar

## 5) Trabajo en Mac (persona no tecnica)

## Paso A - Preparar proyecto iOS

Si no existe carpeta `ios/` en el proyecto Flutter:

```bash
cd turnoapp
flutter create --platforms ios .
flutter pub get
```

## Paso B - Xcode signing

1. Abrir `turnoapp/ios/Runner.xcworkspace`
2. Seleccionar target `Runner`
3. Signing & Capabilities:
   - Team: Apple ID dueño de cuenta developer
   - Bundle Identifier unico (ej: `cl.turnoapp.mobile`)
4. Setear versión y build number

## Paso C - Build para TestFlight

```bash
cd turnoapp
flutter build ios --release
```

Luego en Xcode:
- Product -> Archive
- Distribute App -> App Store Connect -> Upload

## Paso D - App Store Connect metadata

- Nombre app
- Subtitulo
- Descripcion
- Keywords
- URL soporte
- URL privacidad
- Capturas iPhone
- App Privacy (datos recolectados)
- Credenciales demo para App Review

## 6) App Privacy - sugerencia inicial

Declarar (ajustar segun implementacion final exacta):
- Contact Info: Email
- User ID
- Financial info (si aplica por pasarela, no guardar tarjeta en app)
- Location (si solo coordenadas de encuentro se usan manualmente, declarar segun uso real)
- Diagnostics (crash/performance, si aplica)

Nota: si un dato no se transmite off-device, no se declara como “collected”.

## 7) Roadmap de switch a Stripe

Lanzamiento inmediato puede salir con `PAYMENT_PROVIDER=mercadopago`.

Cuando conecten Stripe:
1. Implementar `create-stripe-topup-session` real (Checkout Session / PaymentIntent)
2. Firmar y validar `stripe-webhook` con `stripe-signature`
3. Mantener el mismo contrato de acreditacion en RPC `credit_wallet_topup`
4. Cambiar `PAYMENT_PROVIDER=stripe`

## 8) Comandos utiles Linux/Fedora

```bash
cd "/home/catalystxzr/Escritorio/PERSONAL/uniride"
supabase db push
supabase functions deploy create-topup-intent
supabase functions deploy mercadopago-webhook
supabase functions deploy create-stripe-topup-session
supabase functions deploy stripe-webhook
supabase functions deploy delete-account

cd turnoapp
flutter analyze
flutter build web --release \
  --dart-define=SUPABASE_URL=https://zawaevytpkvejhekyokw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_KEY
```

## 9) Riesgos y mitigacion

- Riesgo: rechazo App Store por falta de delete account.
  - Mitigacion: flujo in-app implementado + notas de review claras.
- Riesgo: incoherencia de saldos por fee topup.
  - Mitigacion: RPC central con `amount_requested`, `amount_charged`, `fee_amount`.
- Riesgo: cambio de proveedor pago en plena ventana de lanzamiento.
  - Mitigacion: feature flag `PAYMENT_PROVIDER`.
