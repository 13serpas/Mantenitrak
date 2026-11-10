import 'vehicle.dart';

/// Pasos del asistente. El barco no tiene paso de zona (solo afecta a
/// neumáticos) ni pide kilómetros.
enum WizardStep {
  type('Tipo'),
  data('Datos'),
  usage('Uso'),
  role('Tu rol'),
  zone('Zona'),
  specs('Ficha técnica');

  const WizardStep(this.label);
  final String label;
}

/// Datos que va rellenando el usuario en el asistente. Los campos de texto se
/// guardan tal cual se escriben; la conversión se hace en [toJson].
class VehicleDraft {
  const VehicleDraft({
    this.type,
    this.brand = '',
    this.model = '',
    this.year = '',
    this.engine = '',
    this.plate = '',
    this.currentKm = '',
    this.annualKm = '',
    this.fuelType = '',
    this.usage = '',
    this.role = 'owner',
    this.zone = 'interior',
  });

  /// Borrador con los datos actuales de un vehículo (para editarlo o pedir
  /// la ficha a la IA desde el detalle).
  factory VehicleDraft.fromVehicle(Vehicle v) => VehicleDraft(
        type: v.type,
        brand: v.brand,
        model: v.model,
        year: v.year > 0 ? '${v.year}' : '',
        engine: v.engine ?? '',
        plate: v.plate ?? '',
        currentKm: v.currentKm?.toString() ?? '',
        annualKm: v.annualKm?.toString() ?? '',
        fuelType: v.fuelType ?? '',
        usage: v.usage ?? '',
        role: v.ownerRole,
        zone: v.zone,
      );

  final VehicleType? type;
  final String brand;
  final String model;
  final String year;
  final String engine;
  final String plate;
  final String currentKm;
  final String annualKm;
  final String fuelType;
  final String usage;
  final String role;
  final String zone;

  static const fuelTypes = ['Gasolina', 'Diésel', 'Híbrido', 'Híbrido enchufable', 'Eléctrico', 'GLP'];
  static const boatFuelTypes = ['Gasolina', 'Diésel', 'Eléctrico'];
  static const usages = ['Ciudad', 'Carretera', 'Mixto', 'Profesional'];

  bool get usesKm => type != VehicleType.barco;
  bool get isElectric => fuelType == 'Eléctrico';
  bool get isDiesel => fuelType == 'Diésel';
  bool get hasStarted => type != null;

  List<WizardStep> get steps => type == VehicleType.barco
      ? WizardStep.values.where((s) => s != WizardStep.zone).toList()
      : WizardStep.values;

  String get title => '$brand $model'.trim();

  VehicleDraft copyWith({
    VehicleType? type,
    String? brand,
    String? model,
    String? year,
    String? engine,
    String? plate,
    String? currentKm,
    String? annualKm,
    String? fuelType,
    String? usage,
    String? role,
    String? zone,
  }) {
    return VehicleDraft(
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      engine: engine ?? this.engine,
      plate: plate ?? this.plate,
      currentKm: currentKm ?? this.currentKm,
      annualKm: annualKm ?? this.annualKm,
      fuelType: fuelType ?? this.fuelType,
      usage: usage ?? this.usage,
      role: role ?? this.role,
      zone: zone ?? this.zone,
    );
  }

  /// Cambiar de tipo vacía marca/modelo/motor (el catálogo es distinto) y,
  /// si deja de aplicar, el combustible.
  VehicleDraft withType(VehicleType t) {
    if (t == type) return this;
    final fuelStillValid = (t == VehicleType.barco ? boatFuelTypes : fuelTypes).contains(fuelType);
    return VehicleDraft(
      type: t,
      year: year,
      plate: plate,
      currentKm: t == VehicleType.barco ? '' : currentKm,
      annualKm: t == VehicleType.barco ? '' : annualKm,
      fuelType: fuelStillValid ? fuelType : '',
      usage: t == VehicleType.barco ? '' : usage,
      role: role,
      zone: t == VehicleType.barco ? 'interior' : zone,
    );
  }

  /// Cambiar de marca vacía el modelo y el motor; cambiar de modelo, el motor.
  VehicleDraft withBrand(String b) =>
      b.trim().toLowerCase() == brand.trim().toLowerCase()
          ? copyWith(brand: b)
          : copyWith(brand: b, model: '', engine: '');

  VehicleDraft withModel(String m) =>
      m.trim().toLowerCase() == model.trim().toLowerCase()
          ? copyWith(model: m)
          : copyWith(model: m, engine: '');

  // ── Validación ────────────────────────────────────────────

  static int? _parseInt(String v) => int.tryParse(v.trim().replaceAll('.', '').replaceAll(' ', ''));

  static String? validateRequired(String v, String what) =>
      v.trim().isEmpty ? 'Introduce $what' : null;

  static String? validateYear(String v, {DateTime? now}) {
    final y = int.tryParse(v.trim());
    final max = (now ?? DateTime.now()).year + 1;
    if (y == null) return 'Introduce el año';
    if (y < 1900 || y > max) return 'Debe estar entre 1900 y $max';
    return null;
  }

  static String? validateCurrentKm(String v) {
    if (v.trim().isEmpty) return 'Introduce los km que marca ahora';
    final n = _parseInt(v);
    if (n == null || n < 0) return 'Escribe solo números';
    if (n > 3000000) return 'Parece demasiado. Revísalo';
    return null;
  }

  /// Opcional: si no se sabe, se calcula con las lecturas futuras.
  static String? validateAnnualKm(String v) {
    if (v.trim().isEmpty) return null;
    final n = _parseInt(v);
    if (n == null || n < 0) return 'Escribe solo números';
    if (n > 500000) return 'Parece demasiado. Revísalo';
    return null;
  }

  bool isStepValid(WizardStep step, {DateTime? now}) => switch (step) {
        WizardStep.type => type != null,
        WizardStep.data => brand.trim().isNotEmpty &&
            model.trim().isNotEmpty &&
            validateYear(year, now: now) == null,
        WizardStep.usage => !usesKm ||
            (validateCurrentKm(currentKm) == null && validateAnnualKm(annualKm) == null),
        WizardStep.role || WizardStep.zone || WizardStep.specs => true,
      };

  bool isComplete({DateTime? now}) => steps.every((s) => isStepValid(s, now: now));

  /// Formato que espera la función SQL `create_vehicle`.
  Map<String, dynamic> toJson() {
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'type': type!.name,
      'brand': brand.trim(),
      'model': model.trim(),
      'year': int.parse(year.trim()),
      'engine': opt(engine),
      'plate': opt(plate)?.toUpperCase(),
      'fuel_type': opt(fuelType),
      'usage': usesKm ? opt(usage) : null,
      'role': role,
      'zone': zone,
      'current_km': usesKm ? _parseInt(currentKm) : null,
      'annual_km': usesKm ? _parseInt(annualKm) : null,
    };
  }

  /// Para `update_vehicle`: igual que [toJson] pero sin km actuales (una
  /// lectura nueva va por `log_km` para que quede en el historial).
  Map<String, dynamic> toUpdateJson() => toJson()..remove('current_km');

  /// Validez del formulario de edición (todo menos los km actuales).
  bool isEditValid({DateTime? now}) =>
      type != null &&
      isStepValid(WizardStep.data, now: now) &&
      (!usesKm || validateAnnualKm(annualKm) == null);
}
