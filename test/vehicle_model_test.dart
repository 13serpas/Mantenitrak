import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';
import 'package:mantenitrak/features/vehicles/presentation/providers/vehicles_provider.dart';
import 'package:mantenitrak/shared/utils/formatters.dart';

/// Fila tal como la devuelve PostgREST con las tablas embebidas.
Map<String, dynamic> row({String owner = 'ana', Object? specs, List<Map<String, dynamic>>? shares}) => {
      'id': 'v1',
      'owner_id': owner,
      'type': 'coche',
      'brand': 'Seat',
      'model': 'Ibiza',
      'year': 2019,
      'engine': '1.0 TSI',
      'plate': '',
      'fuel_type': 'Gasolina',
      'zone': 'costa',
      'current_km': 50000,
      'annual_km': '12000', // NUMERIC/texto también vale
      'vehicle_specs': specs,
      'shared_vehicles': shares ?? [],
      'km_logs': [
        {'km': 50000, 'logged_at': '2026-11-01'},
      ],
      'maintenance_records': [
        {'id': 'm1', 'item_id': 'frenos_del', 'performed_at': '2026-01-10', 'km': 40000, 'cost': '120.50'},
      ],
      'fuel_logs': [
        {'id': 'f1', 'logged_at': '2026-11-01', 'km': 50000, 'liters': 40.5, 'total': 70, 'full_tank': null},
      ],
    };

void main() {
  group('Vehicle.fromJson', () {
    test('propietario, campos opcionales y conversiones', () {
      final v = Vehicle.fromJson(row(specs: {'id': 's1'}), currentUserId: 'ana');
      expect(v.isOwner, isTrue);
      expect(v.type, VehicleType.coche);
      expect(v.plate, isNull); // '' se trata como vacío
      expect(v.subtitle, '2019 · 1.0 TSI');
      expect(v.annualKm, 12000);
      expect(v.hasSpecs, isTrue);
      expect(v.maintenance.single.itemId, 'frenos_delanteros'); // ID antiguo normalizado
      expect(v.maintenance.single.cost, 120.5);
      expect(v.fuelLogs.single.fullTank, isTrue); // null → lleno
      expect(v.kmLogs.single.loggedAt, DateTime(2026, 11, 1));
    });

    test('compartido: toma mi rol de shared_vehicles', () {
      final v = Vehicle.fromJson(
        row(shares: [{'user_id': 'eva', 'role': 'mechanic'}]),
        currentUserId: 'eva',
      );
      expect(v.isOwner, isFalse);
      expect(v.accessRole, AccessRole.mechanic);
      expect(v.hasSpecs, isFalse);
    });

    test('tipo desconocido no rompe', () {
      final v = Vehicle.fromJson({...row(), 'type': 'patinete'}, currentUserId: 'ana');
      expect(v.type, VehicleType.otro);
    });
  });

  test('HomeOverview junta y ordena alertas de todos los vehículos', () {
    final a = Vehicle.fromJson({
      ...row(),
      'id': 'a',
      'maintenance_records': [
        {'id': 'm', 'item_id': 'itv', 'performed_at': '2024-01-01'},
      ],
    }, currentUserId: 'ana');
    final b = Vehicle.fromJson({...row(), 'id': 'b', 'km_logs': []}, currentUserId: 'ana');
    final o = HomeOverview([a, b], now: DateTime(2026, 11, 10));
    expect(o.alerts.first.vehicle.id, 'a');
    expect(o.alerts.first.state.item.id, 'itv');
    expect(o.kmUpdateDue.map((v) => v.id), ['b']);
  });

  group('Fmt', () {
    test('miles y decimales en español', () {
      expect(Fmt.thousands(0), '0');
      expect(Fmt.thousands(999), '999');
      expect(Fmt.thousands(1000), '1.000');
      expect(Fmt.thousands(1234567), '1.234.567');
      expect(Fmt.thousands(-45000), '-45.000');
      expect(Fmt.decimal(6.27), '6,3');
      expect(Fmt.km(45000), '45.000 km');
    });

    test('fechas', () {
      expect(Fmt.date(DateTime(2026, 1, 5)), '05 ene 2026');
      expect(Fmt.date(null), '—');
      expect(Fmt.isoDate(DateTime(2026, 3, 9)), '2026-03-09');
    });
  });
}
