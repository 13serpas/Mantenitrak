import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/fuel/domain/fuel_entry.dart';
import 'package:mantenitrak/features/fuel/domain/fuel_log.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_calculator.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';

Vehicle car({String? fuel = 'Diésel', List<FuelLog> logs = const [], List<KmLog> km = const []}) => Vehicle(
      id: 'v1',
      ownerId: 'u1',
      type: VehicleType.coche,
      brand: 'Seat',
      model: 'León',
      year: 2015,
      accessRole: AccessRole.owner,
      currentKm: 120000,
      fuelType: fuel,
      fuelLogs: logs,
      kmLogs: km,
    );

FuelLog log(String id, DateTime d, int? km, double liters, {bool full = true, String? type = 'Diésel', String? station}) =>
    FuelLog(id: id, loggedAt: d, km: km, liters: liters, fullTank: full, fuelType: type, station: station);

void main() {
  final today = DateTime(2026, 11, 10);

  group('Combustibles según el vehículo', () {
    test('cada vehículo solo ve lo que puede repostar', () {
      expect(FuelEntry.optionsFor('Diésel'), ['Diésel', 'Diésel premium']);
      expect(FuelEntry.optionsFor('Eléctrico'), ['Electricidad']);
      expect(FuelEntry.optionsFor('Híbrido enchufable'), contains('Electricidad'));
      expect(FuelEntry.optionsFor('GLP'), containsAll(['GLP', 'Gasolina 95']));
      expect(FuelEntry.optionsFor(null), FuelEntry.all);
      expect(FuelEntry.all, isNot(contains('AdBlue')));
    });

    test('por defecto, el último combustible usado si encaja', () {
      final v = car(logs: [
        log('a', DateTime(2026, 10, 1), 1000, 40, type: 'Diésel'),
        log('b', DateTime(2026, 11, 1), 1500, 40, type: 'Diésel premium'),
      ]);
      expect(FuelEntry.initial(v, today: today).fuelType, 'Diésel premium');
      expect(FuelEntry.initial(car(fuel: 'Gasolina'), today: today).fuelType, 'Gasolina 95');
      expect(FuelEntry.initial(car(fuel: 'Eléctrico'), today: today).unit, 'kWh');
    });
  });

  group('Dos importes calculan el tercero', () {
    final base = FuelEntry(date: today, fuelType: 'Diésel');

    test('litros y precio → total', () {
      final e = base.withField(FuelField.quantity, '40').withField(FuelField.price, '1,459');
      expect(e.derived, FuelField.total);
      expect(e.total, '58,36');
    });

    test('total y precio → litros (ticket de "50 € de gasoil")', () {
      final e = base.withField(FuelField.total, '50').withField(FuelField.price, '1.459');
      expect(e.quantity, '34,27');
      expect(e.toRpcParams('v1')['p_liters'], isNull, reason: 'el calculado lo recalcula SQL');
      expect(e.toRpcParams('v1')['p_total'], 50);
      expect(e.toRpcParams('v1')['p_price'], closeTo(1.459, 1e-9));
    });

    test('escribir en el calculado cambia cuál se calcula', () {
      var e = base.withField(FuelField.quantity, '40').withField(FuelField.price, '1,5');
      expect(e.total, '60,00');
      e = e.withField(FuelField.total, '57');
      expect(e.derived, FuelField.quantity);
      expect(e.quantity, '38,00');
    });

    test('vaciar un importe de los escritos borra el calculado', () {
      var e = base.withField(FuelField.quantity, '40').withField(FuelField.price, '1,5');
      e = e.withField(FuelField.price, '');
      expect(e.derived, isNull);
      expect(e.total, '');
      expect(e.quantity, '40');
    });

    test('el precio con punto es decimal, no miles', () {
      expect(FuelEntry.parseAmount('1.459'), 1.459);
      expect(FuelEntry.parseAmount('1,459'), 1.459);
      expect(FuelEntry.parseAmount('1.4.5'), isNull);
    });
  });

  group('Validación', () {
    final kmLogs = [KmLog(km: 115000, loggedAt: DateTime(2026, 10, 1))];

    test('hace falta al menos dos importes', () {
      final e = FuelEntry(date: today, fuelType: 'Diésel').withField(FuelField.quantity, '40');
      expect(e.validate(const [], today: today), contains('al menos dos'));
    });

    test('importes fuera de rango', () {
      final e = FuelEntry(date: today, fuelType: 'Diésel')
          .withField(FuelField.quantity, '40')
          .withField(FuelField.price, '15');
      expect(e.validate(const [], today: today), 'Revisa el precio.');
    });

    test('tres importes que no cuadran', () {
      final e = FuelEntry(date: today, quantity: '40', price: '1,5', total: '80');
      expect(e.amountsMismatch, isTrue);
      final ok = FuelEntry(date: today, quantity: '35,21', price: '1,479', total: '52,08');
      expect(ok.amountsMismatch, isFalse, reason: 'el redondeo del surtidor se acepta');
    });

    test('km coherentes con las lecturas (misma regla que mantenimiento)', () {
      final e = FuelEntry(date: today, fuelType: 'Diésel', km: '100000')
          .withField(FuelField.quantity, '40')
          .withField(FuelField.price, '1,5');
      expect(e.validate(kmLogs, today: today), contains('Menos que una lectura anterior'));
      expect(e.copyWith(km: '116000').validate(kmLogs, today: today), isNull);
    });

    test('fecha futura', () {
      final e = FuelEntry(date: today.add(const Duration(days: 1)), fuelType: 'Diésel')
          .withField(FuelField.quantity, '40')
          .withField(FuelField.price, '1,5');
      expect(e.validate(const [], today: today), 'La fecha no puede ser futura.');
    });

    test('aviso de precio raro, sin bloquear', () {
      final e = FuelEntry(date: today, fuelType: 'Diésel').withField(FuelField.price, '0,15');
      expect(e.priceWarning, isNotNull);
      final ev = FuelEntry(date: today, fuelType: 'Electricidad').withField(FuelField.price, '0,15');
      expect(ev.priceWarning, isNull);
    });
  });

  group('Consumo', () {
    final logs = [
      log('a', DateTime(2026, 9, 1), 10000, 40),
      log('b', DateTime(2026, 9, 20), 10300, 15, full: false),
      log('c', DateTime(2026, 10, 10), 10800, 30),
    ];

    test('vista previa del tramo que cierra este lleno', () {
      final e = FuelEntry(date: today, fuelType: 'Diésel', km: '11400')
          .withField(FuelField.quantity, '36')
          .withField(FuelField.price, '1,5');
      final p = e.previewConsumption(logs)!;
      expect(p.value, closeTo(6.0, 0.001)); // 36 L / 600 km
      expect(p.average, closeTo(5.625, 0.001)); // (15 + 30) / 800
      expect(p.unit, 'L/100');
      expect(e.copyWith(fullTank: false).previewConsumption(logs), isNull);
      expect(e.copyWith(km: '10500').previewConsumption(logs), isNull, reason: 'no es el último');
    });

    test('un enchufable no mezcla litros y kWh', () {
      final phev = [
        ...logs,
        log('e1', DateTime(2026, 10, 1), 10500, 9, type: 'Electricidad'),
        log('e2', DateTime(2026, 10, 5), 10600, 9, type: 'Electricidad'),
      ];
      expect(MaintenanceCalculator.averageConsumption(phev), closeTo(5.625, 0.001));
      expect(FuelLog.consumptionUnit(phev), 'L/100');
    });

    test('un eléctrico mide kWh/100 km', () {
      final ev = [
        log('e1', DateTime(2026, 10, 1), 20000, 50, type: 'Electricidad'),
        log('e2', DateTime(2026, 10, 20), 20300, 45, type: 'Electricidad'),
      ];
      expect(MaintenanceCalculator.averageConsumption(ev), closeTo(15, 0.001));
      expect(FuelLog.consumptionUnit(ev), 'kWh/100');
    });

    test('gasolineras recientes sin repetir', () {
      final s = FuelEntry.recentStations([
        log('a', DateTime(2026, 9, 1), null, 40, station: 'Repsol Gran Vía'),
        log('b', DateTime(2026, 10, 1), null, 40, station: 'Cepsa'),
        log('c', DateTime(2026, 11, 1), null, 40, station: 'repsol gran vía'),
      ]);
      expect(s, ['repsol gran vía', 'Cepsa']);
    });
  });
}
