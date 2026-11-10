# Punto 5 · Registrar mantenimientos

## Qué incluye

**Ruta.** La pantalla está en `/vehicles/:id/maintenance`. Con `?items=aceite,filtro_aceite` se abre con esos trabajos ya marcados.

**Cómo se llega.**
- El botón flotante del detalle (pestañas Estado, ¿Qué hacer? e Historial).
- En «¿Qué hacer?»:
  - **"Ya está hecho"** en cada aviso abre el formulario con ese trabajo marcado.
  - **"Ya están hechos: registrarlos"** abre el formulario con todos los pendientes marcados.

**Formulario.**
- **Fecha y km comunes** a todos los trabajos.
  - Los km empiezan con los actuales.
  - Si eliges una fecha pasada y no los has tocado, se vacían, porque un trabajo antiguo no se hizo con los km de hoy.
  - Si escribes km, también quedan como lectura de kilometraje.
  - Se comprueba que encajen: no pueden ser menos que una lectura del mismo día o anterior, ni más que una de un día posterior.
- **Checklist del plan del vehículo, por categorías.**
  - Cada elemento muestra la fecha del último registro y un punto rojo o ámbar si está vencido o próximo.
  - **"Pendientes"** marca solo lo vencido o próximo. Ya no hay botón "Todos" (marcaba hasta la ITV).
- **Cada trabajo marcado** puede llevar su propio coste (admite "89,90" o "1.234,50") y hasta 6 fotos (cámara o galería). Las fotos se reducen a 1.600 px.
- **"Otro trabajo"** sirve para reparaciones que no están en el plan, como escobillas o un faro. Se guarda con `item_id = 'otro'` y su nombre, y no altera los avisos.
- **Taller y observaciones**: un campo común para todos los trabajos.
- **Al guardar**:
  - la barra inferior muestra el total y el progreso de subida ("Subiendo fotos 2 de 5…");
  - si no se puede guardar el registro, se borran las fotos ya subidas;
  - al terminar vuelve al detalle, que se recarga: los avisos se reinician y el inicio se actualiza.
- **Salir sin guardar** con trabajos marcados pide confirmación.

**Historial.**
- Al pulsar un registro se abre su detalle: fecha, km, coste, notas y fotos ampliables.
- Muestra también las fotos antiguas en base64 del prototipo.
- Al borrar un registro se borran también sus fotos de Storage.
- Al eliminar un vehículo se borra su carpeta de fotos.

## Base de datos: migración 006

Ejecuta `supabase/migrations/006_maintenance.sql` en el SQL Editor, después de la 005. Es idempotente y crea:

- **Bucket privado `maintenance-photos`.**
  - Límite de 5 MB por foto; formatos JPG, PNG y WebP.
  - Las fotos se guardan como `<id del vehículo>/<nombre aleatorio>.jpg`.
- **Políticas de Storage.**
  - Ven y suben fotos el propietario y quien tenga el vehículo compartido.
  - Borra quien subió la foto o el propietario del vehículo.
  - Las políticas comentadas del esquema v1 iban por carpeta de usuario, y con ellas el taller no veía las fotos del propietario.
- **`register_maintenance(vehículo, fecha, km, trabajos, notas)`.**
  - Guarda todos los trabajos o ninguno.
  - Valida: fecha no futura, km coherentes, nombre obligatorio en "otro", coste entre 0 y 99.999 €, máximo 6 fotos por trabajo.
  - Solo acepta rutas de fotos de ese mismo vehículo, así que no se pueden enlazar fotos ajenas.
  - Guarda la lectura de km con `log_km` sin duplicarla.

**Pruebas en Postgres 16** (`supabase/tests/t6_mantenimiento.sql`, con Storage simulado):
- varios trabajos con coste en formato español, fotos y notas;
- km coherentes e incoherentes;
- todo o nada;
- un taller compartido puede registrar y un desconocido no;
- permisos de ver, subir y borrar fotos;
- `anon` no puede ejecutar la función.

Las pruebas destaparon un fallo, ya corregido: una lectura más alta el mismo día se rechazaba como "posterior".

## Dependencia nueva: `image_picker`

- **Android y web**: no necesitan configuración. El workflow de GitHub compila igual.
- **iOS**: si algún día compilas para iOS, añade en `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Para hacer fotos de facturas y piezas de tus mantenimientos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Para adjuntar fotos de facturas y piezas a tus mantenimientos.</string>
```

> El código Dart se ha revisado, pero no se ha compilado (no hay SDK de Flutter en este entorno). Si `flutter analyze` o `flutter test` dan algún error, pégalo y lo corregimos.
