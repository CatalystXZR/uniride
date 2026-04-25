# TurnoApp - iOS Build Guide

## Pre-requisitos
- Mac con Xcode instalado
- Cuenta de Apple Developer activa
- Flutter instalado

## Paso 1: Abrir proyecto
```bash
cd turnoapp
open ios/Runner.xcworkspace
```

## Paso 2: Configurar Signing (Xcode)
1. Seleccionar proyecto "Runner" en el navigator
2. Ir a "Signing & Capabilities"
3. Marcar "Automatically manage signing"
4. Seleccionar tu Team ID
5. Verificar Bundle Identifier: `com.uniride.turnoapp` (o crear uno nuevo en Apple Developer Portal)

## Paso 3: Crear Provisioning Profile (si no existe)
1. Ir a Apple Developer Portal → Profiles
2. Crear "App Store" provisioning profile
3. Associate con tu Bundle ID
4. Descargar y Xcode lo detectará automáticamente

## Paso 4: Build para Simulator (prueba rápida)
```bash
cd turnoapp
flutter build ios --simulator --no-codesign
```

## Paso 5: Build para TestFlight
```bash
cd turnoapp
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://tu-proyecto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=tu-anon-key
```

## Paso 6: Subir a TestFlight
1. En Xcode: Product → Archive
2. Una vez completado el archive: "Distribute App"
3. Elegir "App Store Connect"
4. Subir

## Errores comunes y soluciones

| Error | Solución |
|-------|----------|
| "No provisioning profile found" | Crear provisioning profile en Apple Developer Portal |
| "Team ID not found" | Configurar Apple Developer Team en Xcode |
| "Build number already exists" | Incrementar version en pubspec.yaml o en Info.plist |
| "Code signing identity not found" | Regenerar certificados en Keychain Access |

## Notas
- El proyecto ya tiene los permisos de cámara, galería y ubicación configurados en Info.plist
- Background modes para notificaciones push están habilitados
- La app usa Supabase como backend (no requiere configuración adicional)
