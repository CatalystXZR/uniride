# Release Preflight Checklist — TurnoApp v1

Ejecutar antes de cualquier release (TestFlight o web).

---

## Backend (Supabase)

- [ ] `supabase db push` ejecuta todas las migraciones (00 a 22) sin errores
- [ ] `PAYMENT_PROVIDER=disabled` en Edge Function Secrets (sandbox-only release)
- [ ] RPCs verificadas:
  - [ ] `create_booking`
  - [ ] `sandbox_topup` / `sandbox_withdraw`
  - [ ] `delete_user_account`
  - [ ] `complete_ride_manual`
  - [ ] Estado dispatch completo: accept → arriving → arrived → board → start → complete
- [ ] RLS no bloquea lecturas anónimas de `universities` / `campuses`

---

## App (Flutter)

- [ ] `flutter analyze` sin errores
- [ ] Build web: `flutter build web --release --dart-define=...`
- [ ] No hay `print()` ni diálogos raw de error en producción
- [ ] Flujo completo pasajero: buscar → reservar → seguir viaje activo → completar → pantalla arrival
- [ ] Flujo completo conductor: publicar → aceptar pasajero → en camino → llegó → iniciar → finalizar y liquidar
- [ ] Auto-navegación a `/arrival` cuando el viaje se completa
- [ ] Botón "Volver al inicio" en arrival screen redirige a `/home`
- [ ] Sandbox recarga/retiro funciona sin proveedor externo

---

## Deploy Web (Vercel)

- [ ] Deploy desde CI/CD exitoso (vercel-deploy.yml)
- [ ] Rutas estáticas cargan: `/privacy`, `/support`
- [ ] PWA se instala correctamente
- [ ] No hay 404/blank en rutas principales

---

## iOS (TestFlight)

- [ ] Build release: `flutter build ios --release`
- [ ] Archive desde Xcode con `.xcworkspace`
- [ ] Signing configurado (DEVELOPMENT_TEAM en project.pbxproj)
- [ ] `flutter build ipa` genera `.ipa` válido
- [ ] Subida a App Store Connect sin rechazos de cumplimiento
- [ ] TestFlight build instalable en dispositivo real

---

## Documentación

- [ ] README.md actualizado (migraciones, sandbox mode, flujo)
- [ ] TESTFLIGHT_GUIDE.md en `docs/`
- [ ] Runbook de 5 minutos actualizado

---

## Cierre

- [ ] Branch de release mergeada a `main`
- [ ] Tag de versión creado (`v1.0.0-beta1`)
- [ ] Smoke test en prod ejecutado y documentado
