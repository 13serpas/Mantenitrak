# Punto 3 · Alta de vehículo (asistente de 6 pasos)

## Qué incluye

- **Asistente** en `/vehicles/add` con estos pasos: Tipo → Datos → Uso → Tu rol → Zona → Ficha técnica. El barco se salta la zona y no pide km.
  - Al cambiar de tipo se borran marca, modelo y motor; al cambiar de marca, el modelo y el motor; al cambiar de modelo, el motor.
  - El botón atrás del sistema vuelve al paso anterior. Al cerrar con datos introducidos se pide confirmación.
- **Catálogo** de marcas, modelos y motorizaciones por tipo (`vehicle_catalog.dart`), con autocompletado. También se puede escribir texto libre.
- **Ficha técnica** generada con IA o rellenada a mano.
  - La IA se llama desde la Edge Function `vehicle-specs`; la clave de Anthropic nunca llega al móvil.
  - La respuesta se filtra campo a campo (lista blanca, longitudes y litros entre 0 y 60).
- **Guardado atómico** con `rpc('create_vehicle')`: vehículo, primera lectura de km y ficha se guardan en una sola transacción. Si algo falla, no se guarda nada.
- **Modo taller** en el inicio: se activa con el icono 🔧 cuando tienes algún vehículo con rol «Taller».

## Bug encontrado en el esquema

`insert().select()` sobre `vehicles` fallaba siempre. La política de lectura usaba `has_vehicle_access(id)`, que no ve la fila recién insertada.

La migración 004 lo corrige con `owner_id = auth.uid() OR has_vehicle_access(id)`. Esto también afectaba al alta del prototipo antiguo.

## Pasos para desplegar

1. **Migración**: ejecuta `supabase/migrations/004_create_vehicle.sql` en el SQL Editor, después de la 003. Es idempotente.
2. **Edge Function**:
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
   # opcional: supabase secrets set ANTHROPIC_MODEL=claude-haiku-5-5
   supabase functions deploy vehicle-specs
   ```
   Si no está desplegada, la app lo indica y permite rellenar la ficha a mano.
3. **Probar la lógica de la función** (opcional): `deno test supabase/functions/vehicle-specs/`.

## Compilar sin instalar nada: GitHub Actions

El workflow `.github/workflows/build.yml` genera un **APK de depuración** y la **versión web** en cada push a `main`.

1. Sube el proyecto a un repositorio de GitHub.
2. En *Settings → Secrets and variables → Actions*, crea `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
3. En *Actions* verás el build. Dentro de la ejecución, en *Artifacts*, están:
   - `mantenitrak-apk`: descomprímelo e instala `app-debug.apk` en Android (permite «orígenes desconocidos»);
   - `mantenitrak-web`.
4. **Web pública (opcional):** en *Settings → Pages → Source*, elige **GitHub Actions**. La app quedará en `https://<usuario>.github.io/<repo>/`.
   - Añade esa URL en Supabase → *Authentication → URL Configuration → Redirect URLs*, para que funcionen la confirmación de email y Google.
   - Si el repositorio es privado, Pages puede requerir un plan de pago. El APK funciona igual.

## En local

```bash
flutter create . --platforms android,ios,web   # solo la primera vez, si faltan las carpetas
rm -f test/widget_test.dart                    # el que crea flutter create no aplica
flutter pub get
flutter analyze && flutter test
flutter run -d chrome --dart-define-from-file=env.json
```

> El código Dart se ha revisado, pero no se ha podido compilar en el entorno donde se escribió. Si `flutter analyze` o `flutter test` dan algún error, pégalo y lo corregimos.
