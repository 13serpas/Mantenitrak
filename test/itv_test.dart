import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/maintenance/domain/itv_rules.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_calculator.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_catalog.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_record.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';

Vehicle vehicle(VehicleType type, int year, {List<MaintenanceRecord> recs = const []}) => Vehicle(
      id: 'v1',
      ownerId: 'u1',
      type: type,
      brand: 'X',
      model: 'Y',
      year: year,
      accessRole: AccessRole.owner,
      currentKm: 100000,
      maintenance: recs,
    );

MaintenanceRecord itv(DateTime d) => MaintenanceRecord(id: 'itv-$d', itemId: 'itv', performedAt: d);

ItemState itvState(Vehicle v, DateTime now) => MaintenanceCalculator.stateOf(
      MaintenanceCatalog.planFor(v).firstWhere((i) => i.id == 'itv'),
      v,
      now,
    );

void main() {
  final now = DateTime(2026, 11, 10);

  group('Periodicidad (RD 920/2017)', () {
    test('turismos y autocaravanas: bienal hasta 10 años, anual después', () {
      expect(ItvRules.intervalMonths(VehicleType.coche, 4), 24);
      expect(ItvRules.intervalMonths(VehicleType.coche, 9), 24);
      expect(ItvRules.intervalMonths(VehicleType.coche, 10), 12);
      expect(ItvRules.intervalMonths(VehicleType.todoterreno, 15), 12);
      expect(ItvRules.intervalMonths(VehicleType.caravana, 11), 12);
    });

    test('motos y quads: siempre cada 2 años', () {
      expect(ItvRules.intervalMonths(VehicleType.moto, 20), 24);
      expect(ItvRules.intervalMonths(VehicleType.quad, 5), 24);
    });

    test('furgonetas de mercancías, camiones y autobuses', () {
      expect(ItvRules.intervalMonths(VehicleType.furgoneta, 3), 24);
      expect(ItvRules.intervalMonths(VehicleType.furgoneta, 7), 12);
      expect(ItvRules.intervalMonths(VehicleType.furgoneta, 11), 6);
      expect(ItvRules.intervalMonths(VehicleType.camion, 9), 12);
      expect(ItvRules.intervalMonths(VehicleType.camion, 12), 6);
      expect(ItvRules.intervalMonths(VehicleType.autobus, 4), 12);
      expect(ItvRules.intervalMonths(VehicleType.autobus, 6), 6);
      expect(ItvRules.intervalMonths(VehicleType.barco, 6), isNull);
    });
  });

  group('Estado de la ITV', () {
    test('coche de 2015: con más de 10 años toca cada año', () {
      final v = vehicle(VehicleType.coche, 2015, recs: [itv(DateTime(2025, 11, 1))]);
      final s = itvState(v, now);
      expect(s.nextDate, DateTime(2026, 11, 1)); // antes era a los 2 años
      expect(s.status, ItemStatus.danger);
      expect(s.hint, contains('cada año'));
    });

    test('coche de 2019 con ITV a los 4 años: la siguiente a los 2 años', () {
      final v = vehicle(VehicleType.coche, 2019, recs: [itv(DateTime(2025, 6, 1))]);
      final s = itvState(v, now);
      expect(s.nextDate, DateTime(2027, 6, 1));
      expect(s.status, ItemStatus.ok);
    });

    test('coche nuevo sin registro: al día hasta la primera ITV', () {
      final s = itvState(vehicle(VehicleType.coche, 2024), now);
      expect(s.status, ItemStatus.ok);
      expect(s.hint, startsWith('Primera ITV en 2028'));
      // Una vez llega el año, sin registro no se puede saber.
      expect(itvState(vehicle(VehicleType.coche, 2022), now).status, ItemStatus.unknown);
    });

    test('furgoneta de 2014: cada 6 meses', () {
      final v = vehicle(VehicleType.furgoneta, 2014, recs: [itv(DateTime(2026, 6, 1))]);
      final s = itvState(v, now);
      expect(s.nextDate, DateTime(2026, 12, 1));
      expect(s.status, ItemStatus.warning); // más del 80 % del plazo
    });
  });
}
