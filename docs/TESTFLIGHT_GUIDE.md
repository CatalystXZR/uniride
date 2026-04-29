# TurnoApp - Guía TestFlight

## En tu Mac 📱

### 1. Instalar Xcode (20-40 min)
- Abre **App Store** (logo azul en Dock)
- Busca "Xcode"
- Click "Obtener" → "Instalar"

### 2. Instalar Flutter (10 min)
Abre **Terminal** y pega:
```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
```
Después:
```
bash
export PATH="$PATH:$HOME/flutter/bin"
cd ~/flutter
flutter precache
```

### 3. Abrir proyecto
```bash
cd ~/Desktop/uniride/turnoapp
open ios/Runner.xcworkspace
```

### 4. Configurar en Xcode
- Click en **Runner** (nombre del proyecto en el panel izquierdoaz)
- A la derecha busca el panel **Signing & Capabilities**

**Si no ves "Automatically manage signing":**
- Busca el desplegable **Team**
- Selecciona tu cuenta Apple (debe decir "Your Name (Personal Team)")
- El checkbox debería aparecer o dice "Signing requiere un team"

**Si dice "Fix Issue":**
- Click en "Fix Issue" para crear el provisioning profile automáticamente

### 5. Build (8 min)
```bash
cd ~/Desktop/uniride/turnoapp
flutter build ios --release --no-codesign
```

### 6. Subir a TestFlight
- En Xcode: **Product** → **Archive**
- Esperar a que termine
- Click **Distribute App**
- Elegir **App Store Connect**
- **Upload**

---

## Después de subir ⏱️

Apple revisa (1 min - 24 horas)
- Puede ser automático o pedir cambios

Cuando esté aprobado:
- En App Store Connect → TestFlight → Usuarios internos
- Invita testers o usa enlace público

---

## Problemas comunes

| Error | Solución |
|-------|----------|
| "Team not found" | Configura tu Apple ID en Preferences → Accounts |
| "Provisioning" | Das click en "Fix Issue" en Xcode |
| "Build number" | Cambia versión en pubspec.yaml |

---

## Info técnica

- **Bundle ID**: com.uniride.turnoapp
- **Web**: https://turnoapp-nine.vercel.app
- **Supabase**: https://zawaevytpkvejhekyokw.supabase.co