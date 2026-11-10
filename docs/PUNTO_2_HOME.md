# Punto 2 — Pantalla de inicio

## Qué incluye

- **Saludo** con el nombre del usuario.
- **"Necesitan atención"**: las 4 revisiones más urgentes de todos los vehículos (las vencidas primero). Al tocar una se abre el vehículo.
- **"Anota el kilometraje"**: vehículos sin lectura en 30 días. Al tocar uno se abre una hoja para registrar los km. Usa `log_km`, así que funciona también con vehículos compartidos. No acepta valores menores que el último ni saltos de más de 200.000 km.
- **Tarjeta por vehículo**: % de salud, mensaje de estado, km, consumo medio, ficha técnica, rol si es compartido o nº de personas si es tuyo, y recuento de vencidos/próximos/al día.
- Estados de **carga** (siluetas), **vacío** y **error con reintento**. Se puede **tirar para refrescar**.
- En tablet y web la lista se centra con un ancho máximo de 720 px.
- "Añadir vehículo" y el detalle llevan a pantallas provisionales (puntos 3 y 4).

## Archivos nuevos

```
lib/features/
├── vehicles/
│   ├── domain/vehicle.dart                 · Vehicle, VehicleType, AccessRole, KmLog
│   ├── data/vehicle_repository.dart        · 1 consulta con tablas embebidas + log_km
│   └── presentation/
│       ├── home_screen.dart
│       ├── providers/vehicles_provider.dart · vehiclesProvider + HomeOverview
│       └── widgets/ vehicle_health_card · home_notices · km_update_sheet
├── maintenance/
│   ├── domain/ maintenance_catalog · maintenance_calculator · maintenance_record
│   └── presentation/status_tone.dart
└── fuel/domain/fuel_log.dart
lib/shared/ utils/{json,formatters}.dart · widgets/{app_card,status_badge,loading_skeleton,coming_soon_screen}.dart
test/ maintenance_calculator_test.dart · vehicle_model_test.dart
```

## Decisiones

- **Modelos escritos a mano**, sin Freezed: no hace falta `build_runner` y el código se lee igual. Si más adelante quieres `copyWith`/igualdad automáticos, se puede migrar.
- **Una sola consulta** en vez de 7 por vehículo. Con 5 vehículos, el prototipo lanzaba 37 peticiones al abrir la app.
- **Sin tiempo real** por ahora: la lista se recarga al volver a la pantalla, al tirar para refrescar y tras cada cambio. Realtime se puede añadir más adelante si hace falta.
- **Intervalos de mantenimiento**: los mismos del prototipo, más "Discos delanteros" (de `mantenitrak_final.dart`) y un plan básico para barco.

## Corregido respecto al prototipo

| Antes | Ahora |
|---|---|
| Aceite cada 10.000 km para moto y camión | Cada tipo mantiene su intervalo (6.000 / 10.000 / 40.000) |
| Bujías en diésel; aceite y correa en eléctricos | Se omiten según el combustible |
| 31 ene + 1 mes = 3 mar | 28/29 feb |
| Consumo medio ignoraba repostajes parciales | Método "lleno a lleno" con todos los litros |
| Elemento solo por km sin km registrado salía "Al día" | "Sin registrar" |
| IDs distintos entre los dos archivos (`frenos_del` / `frenos_delanteros`) | IDs fijos; los antiguos se convierten al leer |
| Furgoneta, 4x4, autobús, quad… usaban el plan de coche | Cada uno usa el plan que le corresponde |
| La lista seguía mostrando la cuenta anterior tras cambiar de usuario | Se recarga al cambiar de cuenta |

## Pruebas manuales

1. Cuenta nueva → "Aún no tienes vehículos" → botón → pantalla provisional del punto 3.
2. Crea un vehículo desde el SQL Editor (hasta tener el punto 3) → aparece con "Registra los mantenimientos" y el aviso de km.
3. Toca el aviso de km → escribe un valor menor → error; un valor correcto → se guarda y el aviso desaparece.
4. Inserta un `maintenance_records` de `itv` de hace 3 años → el vehículo pasa a rojo y sale en "Necesitan atención".
5. Modo avión → tirar para refrescar → error con "Reintentar".
6. Con una segunda cuenta unida mediante código → ve el vehículo con la etiqueta de su rol.

SQL para el paso 2 (cambia el email):
```sql
insert into vehicles (owner_id, type, brand, model, year, fuel_type, current_km, annual_km)
select id, 'coche', 'Seat', 'Ibiza', 2019, 'Gasolina', 50000, 12000
from auth.users where email = 'tu@email.com';
```
