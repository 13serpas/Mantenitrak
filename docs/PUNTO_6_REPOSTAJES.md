# Punto 6 · Repostajes, coste total repartido e ITV

## 1. Registrar repostaje (o recarga)

**Ruta.** `/vehicles/:id/fuel/add`. Se abre desde el botón flotante de la pestaña Combustible o desde su mensaje vacío.

**Formulario.**
- **Qué has echado.** Solo se ofrece lo que el vehículo puede repostar:

  | Vehículo | Opciones |
  |---|---|
  | Gasolina o híbrido | Gasolina 95, Gasolina 98 |
  | Diésel | Diésel, Diésel premium |
  | GLP | GLP, Gasolina 95, Gasolina 98 (bifuel) |
  | Híbrido enchufable | Gasolina 95, Gasolina 98, Electricidad |
  | Eléctrico | Electricidad |

  - Por defecto aparece el último combustible usado.
  - Ya no está AdBlue, que no es combustible del motor.
- **Fecha y kilómetros.**
  - Los km son opcionales: sin ellos no se calcula el consumo.
  - Siguen la misma regla que en mantenimiento: no pueden ser menos que una lectura del mismo día o anterior, ni más que una de un día posterior.
  - Si se escriben, también quedan como lectura de kilometraje (con `log_km`, que funciona en vehículos compartidos).
- **Importes: dos de tres.** Escribes dos de total, cantidad y precio (los que vengan en el ticket) y la app calcula el tercero.
  - El campo calculado se ve resaltado y con la etiqueta «Calculado».
  - Si escribes en él, pasa a calcularse el que llevabas más tiempo sin tocar.
  - El precio admite «1,459» y «1.459»: en litros y precio, el punto siempre es decimal.
  - Si escribes los tres y no cuadran (margen del 2 % o 10 céntimos, por el redondeo del surtidor), aparece un aviso.
  - Si el precio es raro (menos de 0,60 o más de 3 €/L), se avisa sin impedir guardar.
- **Depósito lleno.** El consumo se calcula de lleno a lleno, sumando los parciales intermedios.
- **Vista previa del consumo.** Si es lleno y con km, se muestra lo que ha gastado este depósito y tu media hasta ahora.
- **Gasolinera.** Se autocompletan las que ya has usado con ese vehículo.
- **Eléctricos.** La cantidad pasa a kWh, el precio a €/kWh, el consumo a kWh/100 km y «lleno» a «carga completa».

## 2. Pestaña Combustible

- **Resumen:** gasto total, litros (o kWh), consumo medio, gasto de este año y coste cada 100 km.
- **Híbridos enchufables:** el consumo se calcula con la gasolina y nunca mezcla litros con kWh. El chip de consumo del inicio muestra la unidad correcta.
- **Borrar:** tus propios repostajes se borran deslizando o con la papelera. La política RLS no deja borrar los de otros.

## 3. Coste total repartido (mejora del punto 5)

- En «Registrar mantenimiento», el selector **«Coste por trabajo / Solo sé el total»** permite escribir un único importe para todos los trabajos marcados.
- La app lo reparte según precios orientativos de taller en España y muestra «≈ X €» en cada trabajo.
- Se guarda con `cost_estimated = true` y se ve con «≈» en el historial y en la ficha del registro.
- La tabla de precios y sus fuentes están en [PRECIOS_REFERENCIA.md](PRECIOS_REFERENCIA.md).
- **Importante:** no son precios de tiendas en directo. Las tiendas de recambios no tienen una API pública de precios y stock. Si más adelante hay acceso a un catálogo, solo cambia esa tabla.

## 4. ITV según tipo y antigüedad (RD 920/2017)

| Tipo | Primera | Después |
|---|---|---|
| Coche, 4x4, autocaravana | 4 años | cada 2 años hasta los 10; **cada año** después |
| Moto, quad | 4 años | cada 2 años |
| Furgoneta (mercancías < 3.500 kg) | 2 años | cada 2 años hasta los 6, cada año hasta los 10, cada 6 meses después |
| Camión | 1 año | cada año hasta los 10, cada 6 meses después |
| Autobús | 1 año | cada año hasta los 5, cada 6 meses después |
| Barco | no pasa ITV | |

- **Un coche de 2015 ya la pasa cada año.**
- El aviso explica la regla («Con 11 años le toca cada año…»).
- Si aún no le toca la primera, sale «Al día» con el año previsto.
- **Límite:** la app solo guarda el año de matriculación, así que el año en que cambia de tramo el cálculo es aproximado.

## 5. Base de datos: migración 007

Ejecútala después de la 006. Es idempotente.

- **`maintenance_records.cost_estimated`**: columna nueva.
- **`assert_km_fits()`**: comprobación de km que comparten mantenimiento y repostajes.
- **`register_maintenance()`**: recreada para guardar `cost_estimated`.
- **`register_fuel()`**:
  - comprueba el acceso al vehículo;
  - calcula el importe que falta y comprueba que los tres cuadran;
  - valida rangos y combustible (lista cerrada);
  - comprueba los km y los guarda en el historial sin duplicar.
- **Trigger `trg_fuel_consumption`**: se retira. Dividía los litros de un solo repostaje sin sumar los parciales; el consumo ya lo calcula la app.
- **Pruebas:** `supabase/tests/t7_repostajes.sql`, ejecutada sobre la cadena completa 001-007 con usuarios simulados. Repasa:
  - los cálculos y las validaciones;
  - km incoherentes;
  - un vehículo compartido;
  - un usuario sin acceso;
  - borrar solo lo propio;
  - que anon no pueda ejecutar nada.

## 6. Archivos

- **Nuevos:**
  - `lib/features/fuel/domain/fuel_entry.dart`
  - `lib/features/fuel/data/fuel_repository.dart`
  - `lib/features/fuel/presentation/add_fuel_screen.dart`
  - `lib/features/maintenance/domain/itv_rules.dart`
  - `lib/features/maintenance/domain/reference_prices.dart`
  - `test/fuel_entry_test.dart`
  - `test/itv_test.dart`
  - `supabase/migrations/007_cost_and_fuel.sql`
- **Modificados:**
  - `fuel_log.dart` (autor, `isElectric`, unidades)
  - `maintenance_calculator.dart` (ITV y consumo por unidad)
  - `maintenance_entry.dart` (modo total)
  - `register_maintenance_screen.dart`
  - `fuel_tab.dart`
  - `history_tab.dart` y `record_sheet.dart` («≈»)
  - `vehicle_repository.dart`
  - `vehicle_detail_provider.dart`
  - `vehicle_health_card.dart`
  - `app_router.dart`
  - `data_failure.dart`

## Cómo probarlo

1. Ejecuta `007_cost_and_fuel.sql` en el editor SQL de Supabase.
2. Ejecuta `flutter pub get`, `flutter analyze` y `flutter test`.
3. Prueba en la app:
   - un repostaje con total y precio;
   - otro con litros y precio;
   - un mantenimiento con «Solo sé el total»;
   - la ITV de un coche anterior a 2016.
