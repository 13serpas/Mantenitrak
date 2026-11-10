import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/core/router/routes.dart';
import 'package:mantenitrak/features/maintenance/data/maintenance_repository.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_catalog.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_entry.dart';
import 'package:mantenitrak/features/maintenance/domain/maintenance_record.dart';
import 'package:mantenitrak/features/maintenance/domain/reference_prices.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';
import 'package:mantenitrak/shared/utils/formatters.dart';

const vid = 'b7298214-35d2-4671-bb6e-e9bb312a7ea8';

MaintenanceItem item(String id) => MaintenanceCatalog.basePlan(VehicleType.coche).firstWhere((i) => i.id == id);

EntryPhoto photo(String id, [String ext = 'jpg']) =>
    EntryPhoto(localId: id, bytes: Uint8List.fromList([1, 2, 3]), extension: ext);

void main() {
  final today = DateTime(2026, 11, 10);
  final plan = MaintenanceCatalog.basePlan(VehicleType.coche);

  group('MaintenanceEntry.initial', () {
    test('hoy, km actuales y trabajos preseleccionados (también IDs antiguos)', () {
      final e = MaintenanceEntry.initial(
        plan: plan,
        preselected: ['aceite', 'frenos_del', 'inventado'],
        currentKm: 61200,
        today: DateTime(2026, 11, 10, 18, 30),
      );
      expect(e.date, today);
      expect(e.km, '61200');
      expect(e.lines.map((l) => l.itemId), ['aceite', 'frenos_delanteros']);
    });
  });

  group('selección', () {
    test('marcar, desmarcar y "solo pendientes" conserva coste y "otros"', () {
      var e = MaintenanceEntry(date: today).toggle(item('aceite'));
      e = e.updateLine('aceite', (l) => l.copyWith(cost: '89,90'));
      e = e.addCustom().addCustom();
      expect(e.lines.map((l) => l.key), ['aceite', 'otro-1', 'otro-2']);

      e = e.selectOnly([item('aceite'), item('itv')]);
      expect(e.lines.map((l) => l.key), ['aceite', 'itv', 'otro-1', 'otro-2']);
      expect(e.lines.first.cost, '89,90');

      e = e.toggle(item('aceite')).removeLine('otro-1');
      expect(e.lines.map((l) => l.key), ['itv', 'otro-2']);
      expect(e.addCustom().lines.last.key, 'otro-1'); // reutiliza el hueco
    });
  });

  group('costes', () {
    test('acepta formato español y con punto', () {
      expect(MaintenanceEntry.parseCost('89,90'), 89.9);
      expect(MaintenanceEntry.parseCost('89.90'), 89.9);
      expect(MaintenanceEntry.parseCost('1.234,50 €'), 1234.5);
      expect(MaintenanceEntry.parseCost('1.234'), 1234);
      expect(MaintenanceEntry.parseCost(''), isNull);
      expect(MaintenanceEntry.validateCost('mucho'), isNotNull);
      expect(MaintenanceEntry.validateCost('100000'), isNotNull);
      expect(MaintenanceEntry.validateCost('120'), isNull);
    });

    test('total suma solo costes válidos', () {
      final e = MaintenanceEntry(date: today, lines: [
        EntryLine.fromItem(item('aceite')).copyWith(cost: '89,90'),
        EntryLine.fromItem(item('itv')).copyWith(cost: '42,5'),
        EntryLine.fromItem(item('bateria')).copyWith(cost: 'x'),
      ]);
      expect(e.total, closeTo(132.4, 1e-9));
    });
  });

  group('km', () {
    final logs = [
      KmLog(km: 40000, loggedAt: DateTime(2026, 4, 24)),
      KmLog(km: 51000, loggedAt: DateTime(2026, 11, 10)),
    ];

    test('opcionales y coherentes con las lecturas', () {
      expect(MaintenanceEntry.validateKm('', today, logs), isNull);
      expect(MaintenanceEntry.validateKm('51500', today, logs), isNull); // mismo día, más km
      expect(MaintenanceEntry.validateKm('45000', DateTime(2026, 8, 1), logs), isNull); // entre lecturas
    });

    test('rechaza menos que una lectura anterior o más que una posterior', () {
      expect(MaintenanceEntry.validateKm('45000', today, logs), contains('Menos que una lectura anterior (51.000 km'));
      expect(MaintenanceEntry.validateKm('42000', DateTime(2026, 1, 1), logs), contains('Más que una lectura posterior (40.000 km'));
      expect(MaintenanceEntry.validateKm('9999999', today, logs), 'Parece demasiado. Revísalo');
    });
  });

  group('validate y parámetros de la función SQL', () {
    test('mensajes de lo que falta', () {
      expect(MaintenanceEntry(date: today).validate(const [], today: today), 'Marca al menos un trabajo.');
      final future = MaintenanceEntry(date: today.add(const Duration(days: 1))).toggle(item('itv'));
      expect(future.validate(const [], today: today), 'La fecha no puede ser futura.');
      final noName = MaintenanceEntry(date: today).addCustom();
      expect(noName.validate(const [], today: today), contains('otro trabajo'));
      final badCost = MaintenanceEntry(date: today).toggle(item('itv')).updateLine('itv', (l) => l.copyWith(cost: 'x'));
      expect(badCost.validate(const [], today: today), 'Revisa el coste de ITV.');
    });

    test('toRpcParams', () {
      final e = MaintenanceEntry(date: today, km: '61.200', notes: '  Taller Pepe ')
          .toggle(item('aceite'))
          .updateLine('aceite', (l) => l.copyWith(cost: '89,90', photos: [photo('p1')]))
          .addCustom()
          .updateLine('otro-1', (l) => l.copyWith(name: ' Escobillas '));
      expect(e.validate(const [], today: today), isNull);
      expect(e.photoCount, 1);

      final params = e.toRpcParams(vid, {'aceite': ['$vid/abc.jpg']});
      expect(params['p_vehicle_id'], vid);
      expect(params['p_date'], '2026-11-10');
      expect(params['p_km'], 61200);
      expect(params['p_notes'], 'Taller Pepe');
      expect(params['p_items'], [
        {'item_id': 'aceite', 'item_name': 'Aceite del motor', 'cost': 89.9, 'cost_estimated': false, 'photos': ['$vid/abc.jpg']},
        {'item_id': 'otro', 'item_name': 'Escobillas', 'cost': null, 'cost_estimated': false, 'photos': <String>[]},
      ]);
    });
  });

  group('solo se sabe el coste total', () {
    MaintenanceEntry totalOf(String total, List<String> ids) {
      var e = MaintenanceEntry(date: today, costMode: CostMode.total, totalCost: total);
      for (final id in ids) {
        e = e.toggle(item(id));
      }
      return e;
    }

    test('reparte según precios de referencia y suma exacto', () {
      final e = totalOf('200', ['aceite', 'filtro_aceite', 'filtro_aire']);
      final costs = e.costsFor(VehicleType.coche);
      // 75 : 15 : 33 → el aceite se lleva la mayor parte.
      expect(costs['aceite'], closeTo(121.96, 0.001)); // + el céntimo sobrante
      expect(costs['filtro_aceite'], closeTo(24.39, 0.001));
      expect(costs.values.fold<double>(0, (a, b) => a + b!), closeTo(200, 1e-9));
      expect(e.total, 200);
      expect(e.costsAreEstimated, isTrue);

      final items = e.toRpcParams(vid, const {}, type: VehicleType.coche)['p_items'] as List;
      expect(items.every((i) => i['cost_estimated'] == true), isTrue);
    });

    test('con un solo trabajo el total es exacto, y los costes por trabajo se ignoran', () {
      final one = totalOf('89,90', ['aceite']).updateLine('aceite', (l) => l.copyWith(cost: 'x'));
      expect(one.validate(const [], today: today), isNull);
      expect(one.costsAreEstimated, isFalse);
      expect(one.costsFor(VehicleType.coche), {'aceite': 89.9});
    });

    test('valida el total y deja vacío si no se escribe', () {
      expect(totalOf('mucho', ['itv']).validate(const [], today: today), 'Revisa el coste total.');
      expect(totalOf('', ['itv', 'bateria']).costsFor(VehicleType.coche), {'itv': null, 'bateria': null});
    });

    test('"otro trabajo" pesa como la mediana; tablas por tipo', () {
      final split = ReferencePrices.split(
        100,
        [(key: 'a', itemId: 'aceite'), (key: 'o', itemId: 'otro')],
        VehicleType.coche,
      );
      expect(split['a'], 50); // mediana de [75] = 75 → mitad y mitad
      expect(split['o'], 50);
      expect(ReferencePrices.of('neumaticos', VehicleType.moto), lessThan(ReferencePrices.of('neumaticos', VehicleType.coche)!));
      expect(ReferencePrices.of('aceite', VehicleType.furgoneta), closeTo(75 * 1.15, 1e-9));
      expect(ReferencePrices.of('inventado', VehicleType.coche), isNull);
    });
  });

  group('fotos', () {
    test('extensiones admitidas por el bucket', () {
      expect(EntryPhoto.extensionOf('IMG_001.JPEG'), 'jpg');
      expect(EntryPhoto.extensionOf('factura.png'), 'png');
      expect(EntryPhoto.extensionOf('foto.heic'), isNull);
      expect(photo('x', 'webp').mimeType, 'image/webp');
    });

    test('ruta en Storage: carpeta del vehículo y nombre aleatorio', () {
      final path = MaintenanceRepository.newPhotoPath(vid, 'jpg', Random(1));
      // Mismo patrón que valida register_maintenance.
      expect(RegExp('^$vid/[A-Za-z0-9_-]{1,80}\\.(jpg|jpeg|png|webp)\$').hasMatch(path), isTrue);
      expect(MaintenanceRepository.newPhotoPath(vid, 'jpg'), isNot(path));
    });

    test('registro: fotos de Storage frente a base64 del prototipo', () {
      final r = MaintenanceRecord.fromJson({
        'id': 'm1',
        'item_id': 'aceite',
        'performed_at': '2026-03-10',
        'photos': ['$vid/a.jpg', 'data:image/jpeg;base64,AAAA', ''],
      });
      expect(r.photoCount, 2);
      expect(r.storagePhotos, ['$vid/a.jpg']);
    });
  });

  test('importes con céntimos', () {
    expect(Fmt.money(89), '89 €');
    expect(Fmt.money(89.9), '89,90 €');
    expect(Fmt.money(1234.5), '1.234,50 €');
  });

  test('ruta con trabajos preseleccionados', () {
    expect(Routes.addMaintenance('v1'), '/vehicles/v1/maintenance');
    expect(Routes.addMaintenance('v1', items: ['aceite', 'itv']), '/vehicles/v1/maintenance?items=aceite,itv');
  });
}
