import 'vehicle.dart';

/// De dónde sale la ficha: IA (orientativa), a mano o leída de una foto.
enum SpecsSource {
  ia,
  manual,
  foto;

  static SpecsSource parse(String? v) =>
      values.firstWhere((s) => s.name == v, orElse: () => manual);

  /// La IA y la lectura de fotos pueden equivocarse: la app lo advierte.
  bool get isAutomatic => this != manual;
}

/// Un campo editable de la ficha técnica.
class SpecField {
  const SpecField(this.key, this.label, this.icon, this.hint, {this.numeric = false});
  final String key;
  final String label;
  final String icon;
  final String hint;
  final bool numeric;
}

/// Ficha técnica (tabla vehicle_specs). Guarda los valores como texto para
/// poder editarlos en formularios; [toJson] los convierte.
class VehicleSpecs {
  const VehicleSpecs({this.values = const {}, this.oilBrands = const [], required this.source});

  factory VehicleSpecs.fromJson(Map<String, dynamic> j, {required SpecsSource source}) {
    final values = <String, String>{};
    for (final f in fields) {
      final v = j[f.key];
      if (v != null && v.toString().trim().isNotEmpty) {
        values[f.key] = f.numeric ? v.toString().replaceAll('.', ',') : v.toString().trim();
      }
    }
    final brands = j['oil_brands'];
    return VehicleSpecs(
      values: values,
      oilBrands: brands is List ? brands.map((b) => b.toString()).toList() : const [],
      source: source,
    );
  }

  static const fields = [
    SpecField('oil_type', 'Aceite', '🛢️', 'ej. 5W-30 VW 504.00'),
    SpecField('oil_liters', 'Litros de aceite', '💧', 'ej. 4,3', numeric: true),
    SpecField('oil_filter_ref', 'Filtro de aceite', '🔵', 'Referencia'),
    SpecField('air_filter_ref', 'Filtro de aire', '💨', 'Referencia'),
    SpecField('cabin_filter_ref', 'Filtro de habitáculo', '🌬️', 'Referencia'),
    SpecField('fuel_filter_ref', 'Filtro de combustible', '⛽', 'Referencia'),
    SpecField('spark_plug_ref', 'Bujías', '⚡', 'Referencia'),
    SpecField('tire_size_front', 'Neumático delantero', '🔘', 'ej. 205/55 R16 91V'),
    SpecField('tire_size_rear', 'Neumático trasero', '🔘', 'ej. 205/55 R16 91V'),
    SpecField('battery_spec', 'Batería', '🔋', 'ej. 70 Ah 640 A'),
  ];

  /// Campos que tienen sentido para este vehículo.
  static List<SpecField> fieldsFor({VehicleType? type, required bool electric, required bool diesel}) {
    const noElectric = {'oil_type', 'oil_liters', 'oil_filter_ref', 'fuel_filter_ref', 'spark_plug_ref'};
    final noCabin = type == VehicleType.moto || type == VehicleType.quad || type == VehicleType.barco;
    final noTyres = type == VehicleType.barco;
    return [
      for (final f in fields)
        if (!(electric && noElectric.contains(f.key)) &&
            !(diesel && f.key == 'spark_plug_ref') &&
            !(noCabin && f.key == 'cabin_filter_ref') &&
            !(noTyres && f.key.startsWith('tire_')))
          f,
    ];
  }

  final Map<String, String> values;
  final List<String> oilBrands;
  final SpecsSource source;

  bool get isEmpty => values.values.every((v) => v.trim().isEmpty);

  /// Ficha guardada en `vehicle_specs` (fila completa embebida).
  static VehicleSpecs? fromRow(Object? row) {
    final map = row is List ? (row.isEmpty ? null : row.first) : row;
    if (map is! Map) return null;
    final j = Map<String, dynamic>.from(map);
    return VehicleSpecs.fromJson(j, source: SpecsSource.parse(j['source'] as String?));
  }

  /// Misma ficha con otro origen (al editar a mano una de IA pasa a "manual").
  VehicleSpecs withSource(SpecsSource s) =>
      VehicleSpecs(values: values, oilBrands: oilBrands, source: s);

  String valueOf(String key) => values[key] ?? '';

  VehicleSpecs withValue(String key, String value) =>
      VehicleSpecs(values: {...values, key: value}, oilBrands: oilBrands, source: source);

  /// Formato que esperan las funciones SQL `create_vehicle` y
  /// `save_vehicle_specs`.
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{'source': source.name};
    for (final f in fields) {
      final v = valueOf(f.key).trim();
      // Lo no válido no se envía (la columna de litros es NUMERIC(4,2)).
      if (v.isEmpty || validateField(f, v) != null) continue;
      out[f.key] = f.numeric ? double.parse(v.replaceAll(',', '.')) : v;
    }
    if (oilBrands.isNotEmpty) out['oil_brands'] = oilBrands;
    return out;
  }

  /// Error de validación de un campo numérico (litros).
  static String? validateField(SpecField f, String v) {
    if (!f.numeric || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim().replaceAll(',', '.'));
    if (n == null || n <= 0 || n > 60) return 'Número entre 0 y 60';
    return null;
  }
}
