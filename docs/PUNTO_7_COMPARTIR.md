# Punto 7 · Compartir vehículo (QR y código)

## Cómo funciona

**El propietario** abre el vehículo → menú ⋮ → **Compartir** (`/vehicles/:id/share`) y ve:
- un **QR** y el **código de 6 caracteres** (por ejemplo «RBM XHZ»), sin 0, 1, I, L ni O para que no se confundan al dictarlo;
- cuándo caduca: a los **7 días**;
- **Copiar** el código y **Enviar**, que abre la hoja de compartir del móvil (WhatsApp, correo…) con un mensaje que lleva el código y el enlace;
- **Generar código nuevo**: el anterior deja de valer y quien ya se ha unido conserva el acceso;
- la **lista de personas con acceso**, con su nombre (ya no el UUID). En cada una puede cambiar el rol (habitual, empresa o taller) o **quitarle el acceso**.

**Quien se une** entra en Inicio → menú ⋮ → **Unirme a un vehículo** (`/join`). Si aún no tiene vehículos, también tiene el enlace «Tengo un código».
- Escanea el QR con la cámara o escribe el código. Se pasa a mayúsculas solo y se ignoran espacios y guiones.
- Elige cómo usa el vehículo. «Soy su taller» hace que aparezca en el modo taller.
- Al unirse se abre el detalle del vehículo.

**Quien tiene acceso compartido** ve en el menú ⋮ «Quién tiene acceso» (el propietario y él mismo) y «Dejar de ver este vehículo». No ve el código ni el lápiz de editar.

**Qué puede hacer cada uno:**
- Quien se une puede ver el estado, el historial y los gastos, y registrar mantenimientos, repostajes y km.
- Solo el propietario edita o elimina el vehículo, cambia la ficha y comparte.
- Lo que registra cada persona se queda en el vehículo aunque luego pierda el acceso.

## Seguridad (migración 008)

| Antes (003) | Ahora (008) |
|---|---|
| El código estaba en `vehicles.share_code`, y cualquiera con acceso (por ejemplo, un taller) podía leerlo y reenviarlo | Está en `vehicle_invites`, sin acceso directo: solo el propietario lo obtiene, con `get_share_invite` |
| No caducaba | Caduca a los 7 días (`regenerate_share_code(id, días)` admite de 1 a 30) |
| Volver a unirse cambiaba el rol | El rol lo decide el propietario (`set_member_role`); volver a unirse no lo cambia |
| Sin límite de personas | Máximo 20 por vehículo |

- **Límite de intentos:** como en la 003, se permiten 10 intentos fallidos por hora.
  - Un código inexistente o caducado no lanza un error SQL, sino que se devuelve en la columna `error`. Si fuera un error SQL, se desharía también el registro del intento y el límite no contaría.
  - La app lo trata igual que cualquier otro error.
- **`vehicle_members`** se ejecuta con los permisos del usuario: el propietario ve a todos, y quien tiene acceso compartido solo se ve a sí mismo y al propietario.
- **Pruebas:** `supabase/tests/t8_compartir.sql`, con tres usuarios simulados sobre las migraciones 001-008. Comprueba:
  - crear y repetir el código;
  - unirse con minúsculas y espacios;
  - que el usuario compartido no pueda ver ni renovar el código, ni cambiar roles;
  - roles no válidos;
  - códigos viejos y caducados;
  - el límite de 10 intentos;
  - salir y quitar el acceso;
  - que anon no pueda ejecutar ninguna de las funciones.

> Las pruebas `t4` y `t5` comprobaban que `share_code` fuera aleatorio. Desde la 008 esa columna queda vacía, y es lo esperado.

## Lo que tienes que configurar

1. **Supabase:** ejecuta `supabase/migrations/008_share_vehicle.sql` después de la 007.
2. **Dependencias nuevas** (ya están en `pubspec.yaml`): `qr_flutter`, `mobile_scanner` y `share_plus`. Ejecuta `flutter pub get`.
3. **Android:**
   - El permiso de cámara lo añade `mobile_scanner` solo.
   - Para que el QR abra la app al leerlo con la cámara normal, añade este intent-filter en `android/app/src/main/AndroidManifest.xml`, junto al de `auth-callback`:
     ```xml
     <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="mantenitrak" android:host="app" />
     </intent-filter>
     ```
   - No pongas `flutter_deeplinking_enabled = false`, o el enlace no llegará a la pantalla de unirse.
4. **iOS:**
   - `NSCameraUsageDescription` ya está en `Info.plist` desde el punto 5 (por las fotos).
   - El esquema `mantenitrak` ya está registrado.
5. **Sin el intent-filter** también funciona: se escanea desde la propia app (Unirme → Escanear QR) o se escribe el código.

## Archivos

- **Nuevos:**
  - `lib/features/sharing/domain/share_code.dart`
  - `lib/features/sharing/data/share_repository.dart`
  - `lib/features/sharing/presentation/share_providers.dart`
  - `lib/features/sharing/presentation/share_vehicle_screen.dart`
  - `lib/features/sharing/presentation/join_vehicle_screen.dart`
  - `lib/features/sharing/presentation/qr_scan_screen.dart`
  - `test/share_code_test.dart`
  - `supabase/migrations/008_share_vehicle.sql`
  - `supabase/tests/t8_compartir.sql`
- **Modificados:**
  - `app_router.dart` (rutas `/join`, `/join/:code` y `share`)
  - `routes.dart`
  - `home_screen.dart` (menú y estado vacío)
  - `vehicle_detail_screen.dart` (menú para quien tiene acceso compartido)
  - `vehicle.dart` (sin `shareCode`)
  - `pubspec.yaml`

## También en esta entrega

- **Registrar mantenimiento:** en la demo, marcar una casilla volvía la lista arriba, porque se redibujaba la pantalla entera. Ahora conserva la posición mientras sigas en la misma pantalla. En la app Flutter la lista ya mantenía la posición; se le ha añadido una `PageStorageKey` para que también la recuerde al volver.
