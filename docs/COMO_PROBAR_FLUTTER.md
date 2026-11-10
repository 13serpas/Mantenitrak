# Cómo ejecutar `flutter analyze` y `flutter test`

- **`flutter analyze`** revisa el código sin ejecutarlo: errores de compilación, imports que faltan y avisos.
- **`flutter test`** ejecuta las pruebas de la carpeta `test/`: cálculos de mantenimiento, ITV, repostajes, códigos de compartir…

Hay dos formas de hacerlo. La A no necesita instalar nada.

---

## A. En GitHub, sin instalar nada

El proyecto trae `.github/workflows/build.yml`, que hace las dos cosas y además genera el APK.

1. Crea un repositorio **privado** en GitHub y sube el contenido de la carpeta `mantenitrak` (con «Add file → Upload files» o con GitHub Desktop).
   - **No subas `env.json`**: lleva tus claves.
2. En el repositorio, entra en **Settings → Secrets and variables → Actions → New repository secret** y crea:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. Abre la pestaña **Actions**. Cada vez que subas cambios a `main` se ejecuta «Compilar y probar». También puedes lanzarla a mano con **Run workflow**.
4. Abre la ejecución y despliega los pasos:
   - **Análisis estático** es el resultado de `flutter analyze`.
   - **Tests** es el de `flutter test`.
   - Si algo falla, sale una ❌ roja. Copia el texto rojo de ese paso y pásamelo.
5. Si todo va bien, en **Artifacts** tienes `mantenitrak-apk` para instalar en un Android.

---

## B. En tu ordenador

### 1. Instalar Flutter (una sola vez)

**Windows**
1. Instala [Git para Windows](https://git-scm.com/download/win), con las opciones por defecto.
2. Instala [Visual Studio Code](https://code.visualstudio.com/) y, dentro, la extensión **Flutter** (de Dart Code). Instala también la de Dart.
3. En VS Code, pulsa `Ctrl+Shift+P`, escribe **Flutter: New Project** y elige **Download SDK**. Elige una carpeta sin espacios ni tildes, como `C:\dev`. Cuando te lo pregunte, acepta **Add SDK to PATH**.
4. Cierra y vuelve a abrir VS Code. Abre una terminal (`Ctrl+ñ` o *Terminal → New Terminal*) y escribe:
   ```
   flutter doctor
   ```
   Para analizar y probar basta con que aparezca ✓ en **Flutter**.
   - **Android toolchain** (Android Studio) solo hace falta para probar en un móvil Android.
   - **Chrome** basta para probar la versión web.

**Mac:** lo mismo con VS Code y la extensión Flutter. Si no tienes Git, la primera vez que lo pida el sistema te ofrecerá instalar las herramientas de línea de comandos de Xcode.

### 2. Preparar el proyecto (una sola vez)

1. Descomprime el zip y abre la carpeta `mantenitrak` en VS Code (*File → Open Folder*).
2. En la terminal de VS Code, crea las carpetas de Android, iOS y web. Esto no toca `lib/` ni `test/`:
   ```
   flutter create . --org com.tuempresa --project-name mantenitrak --platforms android,ios,web
   ```
3. Borra el test de ejemplo que crea Flutter. En Windows:
   ```
   del test\widget_test.dart
   ```
   En Mac:
   ```
   rm test/widget_test.dart
   ```
4. Copia `env.example.json` como `env.json` y rellénalo con la URL y la anon key de Supabase (*Project Settings → API*).

### 3. Analizar y probar (cada vez que te pase una entrega)

```
flutter pub get
flutter analyze
flutter test
```

- **`flutter pub get`** descarga las dependencias. Hay que repetirlo cuando cambia `pubspec.yaml`, como en esta entrega.
- **`flutter analyze`**:
  - Termina en `No issues found!` si todo está bien.
  - Si no, lista líneas como esta:
    ```
    error • The method 'x' isn't defined • lib/…/archivo.dart:12:5 • undefined_method
    ```
  - Los `error` son los importantes. Los `info` (estilo) se pueden ignorar.
- **`flutter test`**: termina en `All tests passed!` o indica qué test ha fallado y por qué.

**Pásame la salida completa** (copiar y pegar o una captura). Con eso corrijo lo que haga falta.

### 4. Arrancar la app

- En el navegador:
  ```
  flutter run -d chrome --dart-define-from-file=env.json
  ```
- En un móvil Android:
  1. Activa las *Opciones de desarrollador* y la *Depuración USB*.
  2. Conéctalo por cable y ejecuta:
     ```
     flutter run --dart-define-from-file=env.json
     ```

La cámara para escanear QR funciona en el móvil y en Chrome (pide permiso).

### Problemas típicos

| Mensaje | Solución |
|---|---|
| `'flutter' no se reconoce como un comando…` | El SDK no está en el PATH. Cierra y vuelve a abrir VS Code; si sigue, repite el paso 3 de la instalación y acepta **Add SDK to PATH** |
| `Because mantenitrak depends on X >=… which requires SDK version…` | Tu Flutter es antiguo: ejecuta `flutter upgrade` |
| `Target of URI doesn't exist: 'package:…'` | Falta `flutter pub get` |
| Error de Gradle o de minSdk al compilar para Android | En `android/app/build.gradle(.kts)`, sube `minSdk` a 23 |
