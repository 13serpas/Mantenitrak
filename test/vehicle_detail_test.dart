import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/core/router/routes.dart';
import 'package:mantenitrak/features/expenses/domain/cost_summary.dart';
import 'package:mantenitrak/features/expenses/domain/expense.dart';
import 'package:mantenitrak/features/fuel/domain/fuel_log.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_calculator.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_catalog.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_help.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_record.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_detail.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_draft.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_specs.dart';
import 'package:mantenitrak/features/vehicles/presentation/detail/vehicle_detail_screen.dart';

/// Fila de detalle tal como la devuelve PostgREST (VehicleRepository.selectDetail).
Map<String, dynamic> detailRow({Object? specs}) => {
      'id': 'v1',
      'owner_id': 'ana',
      'type': 'coche',
      'brand': 'Seat',
      'model': 'Leon',
      'year': 2020,
      'engine': '1.5 TSI',
      'plate': '1234 ABC',
      'fuel_type': 'Diésel',
      'usage': 'Mixto',
      'zone': 'costa',
      'role': 'owner',
      'current_km': 61000,
      'annual_km': 15000,
      'vehicle_specs': specs,
      'shared_vehicles': [
        {'user_id': 'bea', 'role': 'mechanic'},
      ],
      'km_logs': [
        {'km': 61000, 'logged_at': '2026-11-01'},
        {'km': 50000, 'logged_at': '2026-01-15'},
      ],
      'maintenance_records': [
        {
          'id': 'm1', 'user_id': 'ana', 'item_id': 'aceite', 'item_name': 'Aceite del motor',
          'performed_at': '2026-03-10', 'km': 52000, 'cost': '89.90', 'notes': 'Taller Pepe',
          'photos': ['a.jpg', 'b.jpg'],
        },
      ],
      'fuel_logs': [
        {
          'id': 'f1', 'user_id': 'ana', 'logged_at': '2026-10-20', 'km': 60500, 'liters': '40',
          'price_per_liter': null, 'total': 60, 'fuel_type': 'Diésel', 'full_tank': true, 'station': 'Repsol',
        },
      ],
      'expenses': [
        {'id': 'e1', 'user_id': 'ana', 'category': 'seguro', 'amount': '420', 'paid_at': '2026-02-01'},
        {'id': 'e2', 'user_id': 'ana', 'category': 'parking', 'amount': 30, 'paid_at': '2026-11-05'},
        {'id': 'e3', 'user_id': 'ana', 'category': 'raro', 'amount': 5, 'paid_at': '2025-06-01'},
      ],
    };

FuelLog fuel(String id, int km, double liters, {bool full = true, String date = '2026-01-01'}) =>
    FuelLog(id: id, loggedAt: DateTime.parse(date), km: km, liters: liters, fullTank: full);

void main() {
  group('VehicleDetail.fromJson', () {
    test('lee ficha completa, gastos, repostajes y mantenimientos', () {
      final d = VehicleDetail.fromJson(
        detailRow(specs: {'oil_type': '5W-30', 'oil_liters': 4.7, 'source': 'ia', 'oil_brands': ['Castrol']}),
        currentUserId: 'ana',
      );
      expect(d.vehicle.isOwner, isTrue);
      expect(d.vehicle.sharedCount, 1);
      expect(d.specs!.valueOf('oil_liters'), '4,7');
      expect(d.specs!.source, SpecsSource.ia);
      expect(d.specs!.oilBrands, ['Castrol']);

      // Gastos ordenados del más reciente al más antiguo; categoría
      // desconocida → "otros".
      expect(d.expenses.map((e) => e.id), ['e2', 'e1', 'e3']);
      expect(d.expenses.last.category, ExpenseCategory.otros);
      expect(d.expenses[1].amount, 420);

      final f = d.vehicle.fuelLogs.single;
      expect(f.station, 'Repsol');
      expect(f.effectivePricePerLiter, 1.5); // 60 € / 40 L

      final m = d.vehicle.maintenance.single;
      expect(m.userId, 'ana');
      expect(m.photoCount, 2);
      expect(m.cost, 89.9);

      // 61.000 - 50.000 desde la primera lectura.
      expect(d.kmTravelled, 11000);
    });

    test('sin ficha: specs null (también si PostgREST da lista vacía)', () {
      expect(VehicleDetail.fromJson(detailRow(), currentUserId: 'ana').specs, isNull);
      expect(VehicleSpecs.fromRow(const []), isNull);
      expect(VehicleSpecs.fromRow([
        {'oil_type': 'x', 'source': 'foto'},
      ])!.source, SpecsSource.foto);
    });
  });

  group('SpecsSource', () {
    test('parse y aviso de datos automáticos', () {
      expect(SpecsSource.parse('ia').isAutomatic, isTrue);
      expect(SpecsSource.parse('foto').isAutomatic, isTrue);
      expect(SpecsSource.parse(null), SpecsSource.manual);
      expect(SpecsSource.parse('manual').isAutomatic, isFalse);
    });

    test('al corregir una ficha de IA pasa a ser manual', () {
      const s = VehicleSpecs(values: {'oil_type': '5W-30'}, source: SpecsSource.ia);
      final edited = s.withValue('oil_type', '5W-40').withSource(SpecsSource.manual);
      expect(edited.toJson(), {'source': 'manual', 'oil_type': '5W-40'});
    });
  });

  group('VehicleDraft para editar', () {
    final v = VehicleDetail.fromJson(detailRow(), currentUserId: 'ana').vehicle;

    test('fromVehicle copia los datos y toUpdateJson no envía km actuales', () {
      final d = VehicleDraft.fromVehicle(v);
      expect(d.type, VehicleType.coche);
      expect(d.year, '2020');
      expect(d.isDiesel, isTrue);
      expect(d.zone, 'costa');
      final json = d.toUpdateJson();
      expect(json.containsKey('current_km'), isFalse);
      expect(json['annual_km'], 15000);
      expect(json['plate'], '1234 ABC');
      expect(d.isEditValid(now: DateTime(2026, 11, 10)), isTrue);
    });

    test('isEditValid exige marca, modelo y año correctos', () {
      final d = VehicleDraft.fromVehicle(v);
      expect(d.copyWith(model: ' ').isEditValid(), isFalse);
      expect(d.copyWith(year: '1800').isEditValid(), isFalse);
      expect(d.copyWith(annualKm: '999999').isEditValid(), isFalse);
    });
  });

  group('CostSummary', () {
    final now = DateTime(2026, 11, 10);
    final records = [
      MaintenanceRecord(id: 'm1', itemId: 'aceite', performedAt: DateTime(2026, 11, 2), cost: 100),
      MaintenanceRecord(id: 'm2', itemId: 'itv', performedAt: DateTime(2026, 3, 1), cost: 40),
      MaintenanceRecord(id: 'm3', itemId: 'bateria', performedAt: DateTime(2024, 5, 1), cost: 90),
    ];
    final fuelLogs = [
      FuelLog(id: 'f1', loggedAt: DateTime(2026, 11, 5), total: 60),
      FuelLog(id: 'f2', loggedAt: DateTime(2025, 12, 5), total: 50),
    ];
    final expenses = [
      Expense(id: 'e1', category: ExpenseCategory.seguro, amount: 400, paidAt: DateTime(2026, 2, 1)),
      Expense(id: 'e2', category: ExpenseCategory.parking, amount: 20, paidAt: DateTime(2026, 11, 3)),
    ];

    CostSummary sum(CostPeriod p, {int? km}) => CostSummary.compute(
          period: p,
          maintenance: records,
          fuel: fuelLogs,
          expenses: expenses,
          kmTravelled: km,
          now: now,
        );

    test('cada periodo suma solo sus fechas', () {
      final month = sum(CostPeriod.month);
      expect((month.maintenance, month.fuel, month.other), (100, 60, 20));

      final year = sum(CostPeriod.year);
      expect((year.maintenance, year.fuel, year.other), (140, 60, 420));
      expect(year.categoriesSorted.first.key, ExpenseCategory.seguro);

      // Últimos 12 meses: desde el 1 de diciembre de 2025.
      expect(sum(CostPeriod.last12).fuel, 110);
      expect(sum(CostPeriod.all).total, 100 + 40 + 90 + 60 + 50 + 400 + 20);
    });

    test('gráfico de 12 meses que termina en el mes actual', () {
      final s = sum(CostPeriod.month);
      expect(s.months.length, 12);
      expect(s.months.last.month, DateTime(2026, 11));
      expect(s.months.first.month, DateTime(2025, 12));
      expect(s.months.last.total, 180);
    });

    test('€/km solo con todo el histórico y distancia suficiente', () {
      expect(sum(CostPeriod.all, km: 7600).costPerKm, closeTo(760 / 7600, 1e-9));
      expect(sum(CostPeriod.year, km: 7600).costPerKm, isNull);
      expect(sum(CostPeriod.all, km: 50).costPerKm, isNull);
    });
  });

  group('Consumo', () {
    test('tramos lleno a lleno, con repostajes parciales', () {
      final logs = [
        fuel('a', 1000, 40),
        fuel('b', 1300, 10, full: false),
        fuel('c', 1500, 20), // (10 + 20) L / 500 km = 6
        fuel('d', 2000, 30), // 30 / 500 = 6
      ];
      final seg = MaintenanceCalculator.consumptionSegments(logs);
      expect(seg.length, 2);
      expect(seg[0], closeTo(6, 1e-9));
      expect(seg[1], closeTo(6, 1e-9));
      expect(MaintenanceCalculator.consumptionIncrease(logs), isNull); // hacen falta 3 tramos
    });

    test('avisa si el último tramo gasta claramente más que la media', () {
      final logs = [
        fuel('a', 1000, 40),
        fuel('b', 1500, 30), // 6
        fuel('c', 2000, 30), // 6
        fuel('d', 2500, 40), // 8 → +33 %
      ];
      final inc = MaintenanceCalculator.consumptionIncrease(logs)!;
      expect(inc.last, closeTo(8, 1e-9));
      expect(inc.average, closeTo(6, 1e-9));
      expect(inc.percentAbove, 33);

      final normal = [...logs.take(3), fuel('d', 2500, 32)]; // 6,4 → +7 %
      expect(MaintenanceCalculator.consumptionIncrease(normal), isNull);
    });
  });

  test('todas las revisiones de todos los planes tienen explicación', () {
    for (final t in VehicleType.values) {
      for (final item in MaintenanceCatalog.basePlan(t)) {
        expect(MaintenanceHelp.has(item.id), isTrue, reason: '${item.id} (${t.name})');
      }
    }
    expect(MaintenanceHelp.of('desconocido'), MaintenanceHelp.fallback);
  });

  test('rutas y pestañas del detalle', () {
    expect(Routes.vehicleDetail('v1'), '/vehicles/v1');
    expect(Routes.vehicleDetail('v1', tab: 'que-hacer'), '/vehicles/v1?tab=que-hacer');
    expect(Routes.editVehicle('v1'), '/vehicles/v1/edit');
    expect(DetailTab.parse('que-hacer'), DetailTab.whatToDo);
    expect(DetailTab.parse('ficha'), DetailTab.specs);
    expect(DetailTab.parse('inventada'), DetailTab.status);
    expect(DetailTab.parse(null), DetailTab.status);
  });
}
