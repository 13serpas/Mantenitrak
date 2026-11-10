import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/fuel/domain/fuel_log.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_calculator.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_catalog.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_record.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';

Vehicle car({
  VehicleType type = VehicleType.coche,
  String? fuel,
  String? usage,
  String zone = 'interior',
  int? km = 50000,
  List<MaintenanceRecord> recs = const [],
  List<KmLog> kmLogs = const [],
  List<FuelLog> fuelLogs = const [],
}) =>
    Vehicle(
      id: 'v1',
      ownerId: 'u1',
      type: type,
      brand: 'Seat',
      model: 'Ibiza',
      year: 2019,
      accessRole: AccessRole.owner,
      fuelType: fuel,
      usage: usage,
      zone: zone,
      currentKm: km,
      maintenance: recs,
      kmLogs: kmLogs,
      fuelLogs: fuelLogs,
    );

MaintenanceRecord rec(String item, DateTime date, {int? km}) =>
    MaintenanceRecord(id: '$item-$date', itemId: item, performedAt: date, km: km);

MaintenanceItem itemOf(Vehicle v, String id) =>
    MaintenanceCatalog.planFor(v).firstWhere((i) => i.id == id);

void main() {
  final now = DateTime(2026, 11, 10);

  group('Plan por vehículo', () {
    test('cada tipo conserva su intervalo de aceite (antes todos 10.000)', () {
      expect(itemOf(car(), 'aceite').intervalKm, 10000);
      expect(itemOf(car(type: VehicleType.moto), 'aceite').intervalKm, 6000);
      expect(itemOf(car(type: VehicleType.camion), 'aceite').intervalKm, 40000);
    });

    test('ajustes de aceite por combustible y uso', () {
      expect(itemOf(car(fuel: 'Híbrido'), 'aceite').intervalKm, 12000);
      expect(itemOf(car(fuel: 'GLP'), 'aceite').intervalKm, 8000);
      expect(itemOf(car(usage: 'Ciudad'), 'aceite').intervalKm, 8500);
    });

    test('eléctrico sin aceite ni bujías; diésel sin bujías', () {
      final ev = MaintenanceCatalog.planFor(car(fuel: 'Eléctrico')).map((i) => i.id);
      expect(ev, isNot(contains('aceite')));
      expect(ev, isNot(contains('bujias')));
      expect(ev, contains('neumaticos'));
      final diesel = MaintenanceCatalog.planFor(car(fuel: 'Diésel')).map((i) => i.id);
      expect(diesel, isNot(contains('bujias')));
      expect(diesel, contains('aceite'));
    });

    test('neumáticos según zona', () {
      final costa = itemOf(car(zone: 'costa'), 'neumaticos');
      expect(costa.intervalKm, 33000); // 40000 × 0,82 redondeado a 500
      expect(costa.intervalMonths, 42);
      expect(itemOf(car(), 'neumaticos').intervalMonths, 48);
    });

    test('IDs antiguos del prototipo se normalizan', () {
      expect(MaintenanceCatalog.normalizeId('frenos_del'), 'frenos_delanteros');
      expect(MaintenanceCatalog.normalizeId('liq_frenos'), 'liquido_frenos');
      expect(MaintenanceCatalog.normalizeId('aceite'), 'aceite');
    });
  });

  group('Estado de un elemento', () {
    test('sin registros → sin registrar', () {
      final v = car();
      expect(MaintenanceCalculator.stateOf(itemOf(v, 'aceite'), v, now).status, ItemStatus.unknown);
    });

    test('por km: 85 % del intervalo → próximo', () {
      final v = car(km: 58500, recs: [rec('aceite', DateTime(2026, 9, 1), km: 50000)]);
      final s = MaintenanceCalculator.stateOf(itemOf(v, 'aceite'), v, now);
      expect(s.status, ItemStatus.warning);
      expect(s.nextKm, 60000);
    });

    test('por tiempo: pasado de fecha → vencido aunque haya pocos km', () {
      final v = car(km: 50100, recs: [rec('aceite', DateTime(2025, 10, 1), km: 50000)]);
      expect(MaintenanceCalculator.stateOf(itemOf(v, 'aceite'), v, now).status, ItemStatus.danger);
    });

    test('elemento solo por km sin km registrados → sin registrar', () {
      final v = car(recs: [rec('frenos_delanteros', DateTime(2026, 1, 1))]);
      expect(MaintenanceCalculator.stateOf(itemOf(v, 'frenos_delanteros'), v, now).status,
          ItemStatus.unknown);
    });

    test('usa el registro más reciente', () {
      final v = car(km: 51000, recs: [
        rec('aceite', DateTime(2024, 1, 1), km: 30000),
        rec('aceite', DateTime(2026, 10, 1), km: 50000),
      ]);
      expect(MaintenanceCalculator.stateOf(itemOf(v, 'aceite'), v, now).status, ItemStatus.ok);
    });
  });

  group('Utilidades', () {
    test('addMonths no se desborda', () {
      expect(MaintenanceCalculator.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(MaintenanceCalculator.addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(MaintenanceCalculator.addMonths(DateTime(2026, 11, 15), 24), DateTime(2028, 11, 15));
    });

    test('consumo lleno a lleno incluye repostajes parciales', () {
      FuelLog f(int km, double l, {bool full = true}) =>
          FuelLog(id: '$km', loggedAt: now, km: km, liters: l, fullTank: full);
      // 10.000 → 10.500: 20 L parcial + 15 L lleno = 35 L / 500 km = 7,0
      final avg = MaintenanceCalculator.averageConsumption([
        f(10000, 40),
        f(10300, 20, full: false),
        f(10500, 15),
      ]);
      expect(avg, closeTo(7.0, 0.001));
      expect(MaintenanceCalculator.averageConsumption([f(10000, 40)]), isNull);
    });

    test('km/año medidos con lecturas de 30+ días', () {
      final v = car(kmLogs: [
        KmLog(km: 40000, loggedAt: DateTime(2026, 1, 1)),
        KmLog(km: 46000, loggedAt: DateTime(2026, 7, 2)),
      ]);
      final (annual, measured) = MaintenanceCalculator.annualKm(v);
      expect(measured, isTrue);
      expect(annual, closeTo(12033, 50));
    });

    test('salud y alertas ordenadas por urgencia', () {
      final v = car(km: 60500, recs: [
        rec('aceite', DateTime(2026, 6, 1), km: 50000), // 105 % → vencido
        rec('filtro_aire', DateTime(2026, 6, 1), km: 50000), // 52 % → al día
        rec('neumaticos', DateTime(2026, 6, 1), km: 27000), // 84 % → próximo
      ]);
      final h = MaintenanceCalculator.healthOf(v, now: now);
      expect(h.danger, 1);
      expect(h.warning, 1);
      expect(h.ok, 1);
      expect(h.alerts.map((a) => a.item.id), ['aceite', 'neumaticos']);
      expect(h.healthPercent, 33); // 1 al día de 3 registrados
      expect(h.kmUpdateDue, isTrue); // nunca se ha registrado el km
    });
  });
}
