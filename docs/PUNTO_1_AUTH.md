# Punto 1 — Autenticación

## Qué incluye

| Pantalla | Ruta | Notas |
|---|---|---|
| Onboarding | `/onboarding` | Solo la primera vez (se guarda en el dispositivo) |
| Login | `/auth/login` | Email + contraseña, Google, reenviar confirmación |
| Registro | `/auth/register` | Valida nombre, email y contraseña (8+ con letras y números) |
| Recuperar | `/auth/forgot` | No revela si el email existe |
| Nueva contraseña | `/auth/reset-password` | Se abre sola desde el enlace del correo |
| Home (provisional) | `/home` | Solo para comprobar la sesión; es el punto 2 |

Cómo funciona la navegación: **las pantallas nunca navegan tras iniciar o cerrar sesión**. El router escucha a Supabase y redirige. Si alguien abre un enlace (p. ej. `/join/ABC123`) sin sesión, se guarda en `?from=` y vuelve allí después del login.

## Estructura

```
lib/
├── main.dart                 · arranque (Supabase + preferencias)
├── app.dart                  · MaterialApp.router, tema, idioma
├── core/
│   ├── config/env.dart       · claves y URL de retorno
│   ├── providers/            · tema, onboarding, SharedPreferences
│   ├── router/               · rutas + redirecciones
│   ├── supabase/             · cliente y usuario actual
│   └── theme/                · AppTheme + AppColors (context.colors)
├── features/
│   ├── auth/
│   │   ├── data/auth_repository.dart     · única puerta a Supabase Auth
│   │   ├── domain/auth_failure.dart      · errores traducidos
│   │   └── presentation/                 · pantallas + widgets
│   ├── onboarding/
│   └── vehicles/presentation/home_screen.dart  (provisional)
└── shared/  · AppButton, FieldLabel, MessageBanner, Validators
```

## Pasos para ponerlo en marcha

### 1. Base de datos (en este orden, en SQL Editor)
1. `supabase/migrations/001_schema_v1.sql`
2. `supabase/migrations/002_schema_v2.sql`
3. `supabase/migrations/003_seguridad_y_auth.sql` ← **nuevo, obligatorio**

### 2. Supabase → Authentication
- **URL Configuration**
  - Site URL: la URL de tu web (o `http://localhost:3000` mientras desarrollas)
  - Redirect URLs: añade `mantenitrak://auth-callback` y, para web, `http://localhost:*/**`
- **Providers → Email**: confirmación de email activada; *Minimum password length* = 8
- **Providers → Google** (opcional): crea un cliente OAuth "Web application" en Google Cloud y pega Client ID + Secret. En Google Cloud, la URI de redirección autorizada es `https://<tu-proyecto>.supabase.co/auth/v1/callback`
- **Emails** (opcional): traduce las plantillas "Confirm signup" y "Reset password" al español

### 3. Crear el proyecto Flutter y copiar el código
```bash
flutter create mantenitrak --org com.tuempresa --platforms ios,android,web
# copia lib/, test/, pubspec.yaml y analysis_options.yaml encima
cp env.example.json env.json      # rellena URL y anon key
echo "env.json" >> .gitignore
flutter pub get
flutter test
flutter run --dart-define-from-file=env.json
```
`--dart-define-from-file` sustituye al `launch.json` con las claves escritas. En VS Code: `"args": ["--dart-define-from-file=env.json"]`.

### 4. Android — `android/app/src/main/AndroidManifest.xml`
Dentro de `<activity android:name=".MainActivity" …>`, junto al intent-filter existente:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="mantenitrak" android:host="auth-callback" />
</intent-filter>
```

### 5. iOS — `ios/Runner/Info.plist`
El README ya registra el esquema `mantenitrak` (`CFBundleURLTypes`), así que no hay que añadir nada.

> Si al pulsar el enlace del correo la app se abre pero no inicia sesión, desactiva el deep linking propio de Flutter para que lo gestione Supabase:
> Android: `<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />` dentro de `<activity>`.
> iOS: `<key>FlutterDeepLinkingEnabled</key><false/>` en Info.plist.

## Pruebas manuales

1. Primera apertura → onboarding → "Saltar" → login. Cerrar y reabrir la app → va directo al login.
2. Registro con un email nuevo → pantalla "Confirma tu email" → abrir el enlace en el móvil → entra en Home.
3. Registro con un email ya existente → "Ya existe una cuenta con este email".
4. Login sin confirmar el email → aviso con botón "Reenviar correo".
5. Login con contraseña incorrecta → "Email o contraseña incorrectos".
6. Modo avión → login → "No hay conexión con el servidor".
7. "¿Olvidaste la contraseña?" → enlace del correo → pantalla "Nueva contraseña" → guardar → Home.
8. En "Nueva contraseña", intentar salir con el botón atrás → no deja hasta guardar o cancelar.
9. Cerrar sesión desde Home → login. Entrar con otra cuenta → muestra el nombre nuevo.
10. Google → elegir cuenta → vuelve a la app con sesión iniciada.
