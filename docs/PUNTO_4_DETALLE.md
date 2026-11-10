# Punto 4 · Detalle del vehículo

## Qué incluye

**Ruta:** `/vehicles/:id`. Con `?tab=que-hacer` (o `combustible`, `gastos`, `historial`, `ficha`) se abre directamente esa pestaña. Los avisos del inicio ya abren "¿Qué hacer?".

**Cabecera.** Muestra:
- tipo, modelo, salud en %, rol y zona;
- km, km/año (con ✓ si salen de tus lecturas), gasto en mantenimiento y en combustible;
- un aviso de mantenimientos pendientes;
- un aviso de km sin actualizar, que abre la hoja de kilometraje.

**Pestañas.**

| Pestaña | Contenido |
|---|---|
| Estado | Km y todo el plan por categorías: barra del intervalo, último registro, próximo, nota de zona en neumáticos e intervalo recomendado si aún no hay registro. |
| ¿Qué hacer? | Lo vencido y lo próximo, del más urgente al menos. Cada elemento se despliega con una explicación sencilla y qué hacer. Botón "Copiar lista para el taller". |
| Combustible | Gasto, litros y consumo medio (de lleno a lleno). Aviso si el último depósito gasta un 15 % más que tu media. Lista de repostajes con €/L. |
| Gastos | Periodo: este mes / este año / 12 meses / todo. Total, mantenimiento, combustible y otros gastos por categoría. Barras de los últimos 12 meses y €/km del histórico. |
| Historial | Búsqueda y filtro por categoría. Puedes borrar tus propios registros, deslizando o con el botón (con confirmación). |
| Ficha | Ver y copiar la ficha. El propietario puede editarla, pedir una nueva a la IA (la revisa antes de guardar) o quitarla. |

**Botón flotante.** Cambia según la pestaña:
- "Registrar mantenimiento" lleva al punto 5;
- "Registrar repostaje" lleva al punto 6;
- "Añadir gasto" lleva a una fase posterior.

Las rutas ya existen, con pantalla de "pendiente".

**Menú.**
- El propietario puede editar el vehículo y eliminarlo (borra todo su historial, con confirmación).
- Quien lo tiene compartido puede "dejar de verlo".
- "Compartir" lleva al punto 7.

**Editar vehículo** (`/vehicles/:id/edit`). Puedes cambiar:
- tipo, marca, modelo, año, matrícula y motor;
- combustible, uso, km/año, zona y rol.

Los km actuales no se editan aquí: se anotan con "Actualizar kilometraje" para que cada lectura quede en el historial.

## Base de datos: migración 005

Ejecuta `supabase/migrations/005_vehicle_detail.sql` en el SQL Editor, después de la 004. Es idempotente.

- **`update_vehicle(id, datos)`.** Hace las mismas validaciones que el alta. Solo puede usarla el propietario; un usuario compartido recibe "Solo el propietario puede editar este vehículo".
- **`save_vehicle_specs(id, ficha)`.** Guarda la ficha y, si llega vacía, la borra. Admite litros con coma ("4,2") y los limita a 0-60. `create_vehicle` reutiliza esta función, así que el alta y la edición validan igual.
- **Columnas protegidas en `vehicles`.**
  - Antes, el propietario podía cambiar a mano `share_code`, `owner_id` o `current_km`.
  - Ahora solo se pueden actualizar las columnas editables.
  - Los km van por `log_km()` y el código de compartir por `regenerate_share_code()`, que siguen funcionando.

Probado en Postgres 16 con usuarios simulados (`supabase/tests/t5_detalle.sql`, sobre `stub_supabase.sql`):
- la dueña edita y guarda la ficha;
- un taller compartido y un desconocido no pueden editar, cambiar la ficha ni borrar;
- el taller sí puede dejar de ver el vehículo;
- solo quien registró un mantenimiento puede borrarlo;
- borrar el vehículo arrastra todo su historial;
- `anon` no puede ejecutar las funciones;
- el alta (`t4_alta.sql`) sigue pasando.

## Catálogo de marcas y modelos

El catálogo del asistente y de "Editar" pasa de 81 a 185 marcas (contando cada tipo de vehículo por separado), con unos 1.270 modelos. Detalle y fuentes en `docs/CATALOGO_VEHICULOS.md`.

## Pendiente para puntos siguientes

- **Pestaña de viajes y exportar a PDF**: llegan con sus fases. Del prototipo hay que corregir las fuentes del PDF y la consulta de viajes.
- **"Añadir gasto"**: la tabla `expenses` ya se lee aquí, pero el formulario llega más adelante.

> El código Dart se ha revisado, pero no se ha compilado (no hay SDK de Flutter en este entorno). Si `flutter analyze` o `flutter test` dan algún error, pégalo y lo corregimos.
