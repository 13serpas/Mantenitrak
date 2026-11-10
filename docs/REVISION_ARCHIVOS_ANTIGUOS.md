# Revisión de los archivos Flutter del prototipo

Revisados los 14 archivos completos. **Ninguno compila tal cual**: hay `import` a mitad de archivo, clases duplicadas entre archivos, tres versiones distintas de los providers (con `Map`, con Freezed y con `@riverpod`) y referencias a providers que no existen. Por eso no se han parcheado uno a uno. Cada pantalla se rehace en la estructura nueva (`lib/core` + `lib/features`) al llegar a su punto, conservando su diseño y sus textos y corrigiendo los fallos de esta lista.

Leyenda: ✅ ya sustituido · 🔁 recuperado al proyecto nuevo · ⏳ pendiente (punto en que se hará)

## Estado por archivo

| Archivo | Contenido | Estado |
|---|---|---|
| `flutter_main.dart` | main, tema, router, modelos Freezed, repositorios, notificaciones | ✅ Puntos 1-2 |
| `flutter_final_wiring.dart` | main y router "finales", checklist de viaje | ✅ router · ⏳ checklist de viaje |
| `flutter_auth_screens.dart` | login, registro, recuperar, splash | ✅ Punto 1 · 🔁 aviso de términos |
| `flutter_shared_widgets.dart` | botón, campo, logo, badge, tarjeta, filtros… | ✅ casi todo · 🔁 `AppLogo`, diálogo de confirmación, estado vacío y filtro de periodo (punto 4) |
| `flutter_maintenance_calculator.dart` | calculadora de mantenimiento | ✅ Punto 2 |
| `flutter_providers.dart` | todos los providers (versión `@riverpod`) | ✅ vehículos y km · ⏳ CRUD de mantenimiento, combustible y gastos |
| `flutter_screens.dart` | Home + detalle (versión `Map`) | ✅ Home y detalle · 🔁 modo taller, rol en tarjeta, editar y eliminar |
| `flutter_vehicle_detail.dart` | detalle (versión `Vehicle`) con pestaña de viajes | ✅ Punto 4 · ⏳ pestaña de viajes y PDF (fases posteriores) |
| `flutter_wizard_checklist_fuel_expense_router.dart` | asistente, checklist, repostaje, gasto, router | ✅ asistente (3) · ⏳ checklist (5), repostaje (6), gasto |
| `flutter_trips_share_tyre_onboarding_profile.dart` | viajes, compartir, unirse, neumático IA, onboarding, perfil, notificaciones | ✅ onboarding · ⏳ compartir/unirse (7) y resto |
| `flutter_final_complete.dart` | app completa en un archivo (idéntico al ya revisado) | ✅ referencia |
| `flutter_completion.dart` | PDF, resumen de gastos, copia en Drive | ⏳ posteriores |
| `flutter_expense_summary_trip_detail.dart` | resumen de gastos con fl_chart, resumen de viaje | ⏳ posteriores |
| `flutter_domains.dart` | modelos Freezed de viaje, gasto, copia; repositorios | ⏳ posteriores (se reescriben sin Freezed) |

## Fallos encontrados y qué se ha hecho

### Ya corregidos (puntos 1-5 y migraciones)
- **IA llamada desde la app sin clave** (asistente, neumático, ficha por foto). No funcionaba, y con clave la habría expuesto. → Edge Function `vehicle-specs` (punto 3). El análisis de neumático y la ficha por foto usarán la misma vía.
- **`insert().select()` en `vehicles` fallaba siempre** por la política RLS de lectura. El asistente antiguo nunca podía crear un vehículo. → Migración 004.
- **Ficha de la IA en camelCase** (`oilType`) insertada en columnas snake_case (`oil_type`): el insert fallaba. → La función de servidor devuelve snake_case y la función SQL filtra las columnas.
- **Alta en 3 llamadas sueltas**: si la segunda fallaba, quedaba un vehículo sin su lectura de km. → `create_vehicle` en una transacción.
- **`'León'` en la lista de motores y `'Leon'` en la de modelos**: nunca coincidían.
- **El código de compartir lo generaba la app a partir de la hora**: era predecible. → Generado en servidor (003).
- **`currentUserProvider` no se actualizaba** al cambiar de cuenta.
- **Actualizar km con `UPDATE vehicles`** fallaba en silencio para usuarios compartidos. → `log_km` (003).
- **Redirecciones de auth** a `io.mantenitrak://login-callback` y `…/reset-callback`, que no estaban registradas. Además faltaba la pantalla de nueva contraseña. → Punto 1.
- **Detalle (punto 4)**: "Eliminar vehículo" pedía confirmación pero no borraba nada; `_showKmModal` no abría la hoja; el botón flotante no cambiaba con la pestaña; `colors.warningLight ?? …` y `Color(0xFF7C3AED')` no compilaban; `firstWhere(orElse: items.first)` mostraba como "Aceite" cualquier registro desconocido; el detalle lanzaba 7 consultas. → Pantalla nueva con una sola consulta.
- **Registrar mantenimiento (punto 5)**: las fotos se guardaban en base64 dentro de la fila (cientos de KB cada una); el coste solo se guardaba si marcabas un único trabajo; los km se escribían con `UPDATE` directo (fallaba con vehículos compartidos) y sin comprobar que encajaran con las lecturas; "Todos" marcaba hasta la ITV. → Fotos en Storage, coste por trabajo, función `register_maintenance` atómica (migración 006).
- **`get_expense_summary`**: el semestre dependía del mes actual aunque se pidiera otro año, y el desglose mensual no cuadraba con periodos que no empiezan el día 1. → El resumen de gastos se calcula en la app (`CostSummary`).
- **Columnas de `vehicles` sin proteger**: el propietario podía cambiar a mano `share_code`, `owner_id` o `current_km` (sin lectura en el historial). → Migración 005.
- **Calculadora**: aceite de 10.000 km para motos y camiones, bujías en diésel, aceite en eléctricos, fechas que se desbordan y consumo sin repostajes parciales. → Punto 2.

- **Repostaje**: la lista de combustibles no tenía GLP ni electricidad (y sí AdBlue), los km se escribían con un UPDATE directo que fallaba en vehículos compartidos, y el trigger de consumo dividía los litros de un solo repostaje sin sumar los parciales. → Punto 6 y migración 007.

- **Compartir**: "Copiar enlace" no copiaba nada, la lista de accesos mostraba el UUID de cada usuario, `AppTextField(suffix: …)` no compilaba y cualquiera con acceso podía leer el código en `vehicles.share_code`. → Punto 7 y migración 008.

### Pendientes, a corregir al portar cada pantalla

**Gastos**
- Próximo vencimiento: `DateTime(año, mes + n, día)` se desborda (31 ene + 1 mes = 3 mar). Usar `MaintenanceCalculator.addMonths`.
- `double.parse(_amount.text)` revienta con "12,50". Validar el importe.
- `Navigator.pushNamed` con go_router no funciona (`flutter_expense_summary_trip_detail.dart`).

**Viajes**
- Al cerrar un viaje la app también inserta la lectura de km. Ahora lo hace el trigger (003), así que quedaría duplicada.
- `TripRepository.fetchTrips` usa `fuel_logs!inner`, pero `trips` y `fuel_logs` no están relacionadas: PostgREST da error.
- La checklist decide si el viaje es largo según los km/año del coche, no según el viaje.

**Neumático IA**
- `_result!['wearPct'] as int` revienta si la IA devuelve `35.0`.

**PDF, copia en Drive, notificaciones**
- PDF: los emojis no se ven con la fuente por defecto del paquete `pdf`. Hace falta incrustar una fuente.
- Restaurar copia hace `upsert` en **todas** las tablas del JSON, incluida `shared_vehicles`. Debe limitarse a los datos propios.
- El perfil simula la copia (`Future.delayed`) y el interruptor de notificaciones no hace nada.

## Cosas del prototipo que no se han recuperado (decisión)
- **Fuentes Syne / Plus Jakarta Sans**: el tema las declara, pero los archivos de fuente no están en el proyecto. Se pueden añadir cuando tengas los `.ttf`.
- **Pantalla splash**: no hace falta; la sesión se restaura antes del primer fotograma.
- **Freezed + build_runner**: los modelos van escritos a mano. Es menos magia y no hay que regenerar código.
