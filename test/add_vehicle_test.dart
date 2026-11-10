import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_catalog.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_draft.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle_specs.dart';

void main() {
  final now = DateTime(2026, 11, 10);
  const complete = VehicleDraft(
    type: VehicleType.coche,
    brand: ' Seat ',
    model: 'Ibiza',
    year: '2019',
    plate: '4521 hjk',
    currentKm: '50.000',
    fuelType: 'Gasolina',
    usage: 'Ciudad',
  );

  group('VehicleDraft: validación', () {
    test('año', () {
      expect(VehicleDraft.validateYear('', now: now), isNotNull);
      expect(VehicleDraft.validateYear('1899', now: now), isNotNull);
      expect(VehicleDraft.validateYear('2028', now: now), isNotNull);
      expect(VehicleDraft.validateYear('2027', now: now), isNull); // modelos del año siguiente
    });

    test('km actuales obligatorios, km/año opcionales', () {
      expect(VehicleDraft.validateCurrentKm(''), isNotNull);
      expect(VehicleDraft.validateCurrentKm('45.000'), isNull);
      expect(VehicleDraft.validateCurrentKm('9999999'), isNotNull);
      expect(VehicleDraft.validateAnnualKm(''), isNull);
      expect(VehicleDraft.validateAnnualKm('900000'), isNotNull);
    });

    test('cada paso exige lo suyo', () {
      const empty = VehicleDraft();
      expect(empty.isStepValid(WizardStep.type), isFalse);
      expect(empty.copyWith(type: VehicleType.moto).isStepValid(WizardStep.type), isTrue);
      expect(complete.isStepValid(WizardStep.data, now: now), isTrue);
      expect(complete.copyWith(model: ' ').isStepValid(WizardStep.data, now: now), isFalse);
      expect(complete.copyWith(currentKm: '').isStepValid(WizardStep.usage), isFalse);
      expect(complete.isComplete(now: now), isTrue);
    });
  });

  group('VehicleDraft: cambios encadenados', () {
    test('cambiar de marca vacía modelo y motor', () {
      final d = complete.copyWith(engine: '1.0 TSI').withBrand('Renault');
      expect(d.model, '');
      expect(d.engine, '');
      // misma marca con otras mayúsculas: no borra nada
      expect(complete.withBrand('SEAT').model, 'Ibiza');
    });

    test('barco: sin paso de zona, sin km y combustible compatible', () {
      final boat = complete.copyWith(fuelType: 'GLP').withType(VehicleType.barco);
      expect(boat.steps, isNot(contains(WizardStep.zone)));
      expect(boat.steps.length, 5);
      expect(boat.brand, ''); // otro catálogo
      expect(boat.currentKm, '');
      expect(boat.fuelType, ''); // GLP no se ofrece en barcos
      expect(boat.usesKm, isFalse);
      expect(boat.isStepValid(WizardStep.usage), isTrue);
    });
  });

  test('toJson: limpia, normaliza y omite lo vacío', () {
    final j = complete.toJson();
    expect(j['type'], 'coche');
    expect(j['brand'], 'Seat');
    expect(j['year'], 2019);
    expect(j['plate'], '4521 HJK');
    expect(j['current_km'], 50000);
    expect(j['annual_km'], isNull);
    expect(j['engine'], isNull);
    expect(j['role'], 'owner');
    expect(j['zone'], 'interior');
  });

  group('VehicleSpecs', () {
    test('desde la IA: decimales con coma y marcas', () {
      final s = VehicleSpecs.fromJson(
        {'oil_type': '5W-30', 'oil_liters': 4.3, 'oil_brands': ['Castrol'], 'spark_plug_ref': null},
        source: SpecsSource.ia,
      );
      expect(s.valueOf('oil_liters'), '4,3');
      expect(s.valueOf('spark_plug_ref'), '');
      expect(s.oilBrands, ['Castrol']);
    });

    test('toJson descarta números inválidos y lo vacío', () {
      final s = const VehicleSpecs(source: SpecsSource.manual)
          .withValue('oil_liters', '400')
          .withValue('oil_type', ' 0W-20 ')
          .withValue('battery_spec', '');
      final j = s.toJson();
      expect(j['source'], 'manual');
      expect(j['oil_type'], '0W-20');
      expect(j.containsKey('oil_liters'), isFalse);
      expect(j.containsKey('battery_spec'), isFalse);
      expect(s.withValue('oil_liters', '4,5').toJson()['oil_liters'], 4.5);
    });

    test('campos según vehículo', () {
      List<String> keys(VehicleType t, {bool ev = false, bool diesel = false}) =>
          VehicleSpecs.fieldsFor(type: t, electric: ev, diesel: diesel).map((f) => f.key).toList();
      expect(keys(VehicleType.coche, ev: true), isNot(contains('oil_type')));
      expect(keys(VehicleType.coche, diesel: true), isNot(contains('spark_plug_ref')));
      expect(keys(VehicleType.moto), isNot(contains('cabin_filter_ref')));
      expect(keys(VehicleType.barco), isNot(contains('tire_size_front')));
      expect(keys(VehicleType.coche), contains('tire_size_front'));
    });
  });

  group('VehicleCatalog', () {
    test('marcas y modelos por tipo, sin distinguir mayúsculas', () {
      expect(VehicleCatalog.brands(VehicleType.moto), contains('Yamaha'));
      expect(VehicleCatalog.brands(VehicleType.furgoneta), contains('Renault'));
      expect(VehicleCatalog.models(VehicleType.coche, 'seat'), contains('Ibiza'));
      expect(VehicleCatalog.models(VehicleType.furgoneta, 'Renault'), contains('Kangoo'));
      expect(VehicleCatalog.brands(VehicleType.otro), isEmpty);
    });

    test('motores y filtro', () {
      expect(VehicleCatalog.engines('Seat', 'leon'), isNotEmpty);
      expect(VehicleCatalog.engines('Seat', 'Desconocido'), isEmpty);
      expect(VehicleCatalog.filter(['Ibiza', 'Leon', 'Arona'], 'on').toList(), ['Leon', 'Arona']);
    });

    test('sin acentos: citroen, león, tenere', () {
      expect(VehicleCatalog.models(VehicleType.coche, 'citroen'), contains('C4'));
      expect(VehicleCatalog.engines('Seat', 'León'), isNotEmpty);
      expect(VehicleCatalog.filter(['Ténéré 700', 'MT-07'], 'tenere').toList(), ['Ténéré 700']);
      expect(VehicleCatalog.normalize('  Citroën   C4 '), 'citroen c4');
    });

    test('gama actual y modelos de años anteriores', () {
      // Marcas llegadas en los últimos años.
      for (final b in ['BYD', 'MG', 'Omoda', 'Jaecoo', 'Ebro', 'Leapmotor', 'Cupra']) {
        expect(VehicleCatalog.brands(VehicleType.coche), contains(b));
      }
      expect(VehicleCatalog.models(VehicleType.coche, 'BYD'), contains('Seal U DM-i'));
      expect(VehicleCatalog.models(VehicleType.moto, 'Zontes'), contains('368G'));
      expect(VehicleCatalog.models(VehicleType.moto, 'Voge'), contains('900 DSX'));
      // Modelos que ya no se venden pero siguen circulando.
      expect(VehicleCatalog.models(VehicleType.coche, 'Seat'), containsAll(['Altea', 'Exeo', 'Córdoba']));
      expect(VehicleCatalog.brands(VehicleType.coche), containsAll(['Chevrolet', 'Saab', 'Rover']));
    });

    test('marcas ordenadas y sin modelos repetidos', () {
      for (final t in VehicleType.values) {
        final brands = VehicleCatalog.brands(t);
        final sorted = [...brands]..sort((a, b) => VehicleCatalog.normalize(a).compareTo(VehicleCatalog.normalize(b)));
        expect(brands, sorted, reason: 'marcas de ${t.name}');
        for (final b in brands) {
          final models = VehicleCatalog.models(t, b);
          expect(models.toSet().length, models.length, reason: '$b (${t.name})');
        }
      }
    });

    test('barcos: motores marinos si el modelo no tiene lista propia', () {
      expect(VehicleCatalog.engines('Beneteau', 'Flyer', type: VehicleType.barco), contains('Yamaha F150'));
      expect(VehicleCatalog.engines('Beneteau', 'Flyer'), isEmpty);
    });
  });

  test('Vehicle.isWorkshop: compartido como taller o dado de alta como taller', () {
    Vehicle v(String owner, String role, List<Map<String, dynamic>> shares) => Vehicle.fromJson({
          'id': 'v',
          'owner_id': owner,
          'type': 'coche',
          'brand': 'Seat',
          'model': 'Ibiza',
          'year': 2019,
          'role': role,
          'shared_vehicles': shares,
        }, currentUserId: 'yo');
    expect(v('yo', 'mechanic', []).isWorkshop, isTrue);
    expect(v('yo', 'owner', []).isWorkshop, isFalse);
    expect(v('otro', 'owner', [{'user_id': 'yo', 'role': 'mechanic'}]).isWorkshop, isTrue);
    // El rol del propietario no convierte en taller a quien lo ve compartido
    expect(v('otro', 'mechanic', [{'user_id': 'yo', 'role': 'regular'}]).isWorkshop, isFalse);
  });
}
