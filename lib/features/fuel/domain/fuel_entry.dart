import '../../../shared/utils/formatters.dart';
import '../../maintenance/domain/maintenance_calculator.dart';
import '../../maintenance/domain/maintenance_entry.dart';
import '../../vehicles/domain/vehicle.dart';
import 'fuel_log.dart';

/// Los tres importes de un repostaje. Con dos se calcula el tercero.
enum FuelField { quantity, price, total }

/// Formulario de "Registrar repostaje" (punto 6), sin Flutter para poder
/// probarlo. Mismas reglas que la función SQL `register_fuel`.
class FuelEntry {
  const FuelEntry({
    required this.date,
    this.km = '',
    this.quantity = '',
    this.price = '',
    this.total = '',
    this.fullTank = true,
    this.fuelType,
    this.station = '',
    this.recent = const [],
  });

  /// Formulario nuevo: hoy, con el combustible del último repostaje si
  /// encaja con el vehículo, o el primero que le corresponde.
  factory FuelEntry.initial(Vehicle v, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final options = optionsFor(v.fuelType);
    final logs = [...v.fuelLogs]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final last = logs.map((f) => f.fuelType).firstWhere((t) => t != null && options.contains(t), orElse: () => null);
    return FuelEntry(date: DateTime(now.year, now.month, now.day), fuelType: last ?? options.first);
  }

  final DateTime date;
  final String km;
  final String quantity;
  final String price;
  final String total;
  final bool fullTank;
  final String? fuelType;
  final String station;

  /// Los dos últimos importes que ha escrito el usuario (el más reciente
  /// primero). El tercero es el que se calcula.
  final List<FuelField> recent;

  // ── Combustibles (lista cerrada, igual que en SQL) ───────────

  static const all = ['Gasolina 95', 'Gasolina 98', 'Diésel', 'Diésel premium', 'GLP', 'GNC', FuelLog.electricity];

  /// Lo que puede repostar un vehículo según su combustible.
  /// Un GLP es bifuel (también gasolina); un enchufable, gasolina y red.
  static List<String> optionsFor(String? vehicleFuel) => switch (vehicleFuel) {
        'Gasolina' || 'Híbrido' => const ['Gasolina 95', 'Gasolina 98'],
        'Diésel' => const ['Diésel', 'Diésel premium'],
        'Híbrido enchufable' => const ['Gasolina 95', 'Gasolina 98', FuelLog.electricity],
        'Eléctrico' => const [FuelLog.electricity],
        'GLP' => const ['GLP', 'Gasolina 95', 'Gasolina 98'],
        _ => all,
      };

  bool get isElectric => fuelType == FuelLog.electricity;
  String get unit => isElectric ? 'kWh' : 'L';
  String get priceUnit => isElectric ? '€/kWh' : '€/L';

  // ── Edición ──────────────────────────────────────────────────

  FuelEntry copyWith({
    DateTime? date,
    String? km,
    bool? fullTank,
    String? fuelType,
    String? station,
  }) =>
      FuelEntry(
        date: date ?? this.date,
        km: km ?? this.km,
        quantity: quantity,
        price: price,
        total: total,
        fullTank: fullTank ?? this.fullTank,
        fuelType: fuelType ?? this.fuelType,
        station: station ?? this.station,
        recent: recent,
      );

  String valueOf(FuelField f) => switch (f) {
        FuelField.quantity => quantity,
        FuelField.price => price,
        FuelField.total => total,
      };

  /// El importe que se está calculando solo (null si aún no hay dos).
  FuelField? get derived => recent.length < 2 ? null : FuelField.values.firstWhere((f) => !recent.contains(f));

  /// El usuario escribe en [field]. Si ya hay otro importe escrito por él,
  /// se recalcula el tercero. Borrar un campo deja de usarlo para calcular.
  FuelEntry withField(FuelField field, String text) {
    final typed = text.trim().isNotEmpty;
    final order = [
      if (typed) field,
      ...recent.where((f) => f != field),
    ].take(2).toList();
    final values = {
      FuelField.quantity: quantity,
      FuelField.price: price,
      FuelField.total: total,
    };
    values[field] = text;
    // Si se ha borrado un campo que alimentaba el cálculo, el calculado
    // también deja de valer.
    final oldDerived = derived;
    if (oldDerived != null && !order.contains(oldDerived) && order.length < 2) {
      values[oldDerived] = '';
    }
    final next = FuelEntry(
      date: date,
      km: km,
      quantity: values[FuelField.quantity]!,
      price: values[FuelField.price]!,
      total: values[FuelField.total]!,
      fullTank: fullTank,
      fuelType: fuelType,
      station: station,
      recent: order,
    );
    return next._recalculate();
  }

  FuelEntry _recalculate() {
    final d = derived;
    if (d == null) return this;
    final q = parseAmount(quantity);
    final p = parseAmount(price);
    final t = MaintenanceEntry.parseCost(total);
    String out = '';
    switch (d) {
      case FuelField.total:
        if (q != null && p != null) out = Fmt.decimal(q * p, 2);
      case FuelField.quantity:
        if (t != null && p != null && p > 0) out = Fmt.decimal(t / p, 2);
      case FuelField.price:
        if (t != null && q != null && q > 0) out = Fmt.decimal(t / q, 3);
    }
    return FuelEntry(
      date: date,
      km: km,
      quantity: d == FuelField.quantity ? out : quantity,
      price: d == FuelField.price ? out : price,
      total: d == FuelField.total ? out : total,
      fullTank: fullTank,
      fuelType: fuelType,
      station: station,
      recent: recent,
    );
  }

  // ── Números ──────────────────────────────────────────────────

  static const maxQuantity = 999.0;
  static const maxPrice = 9.999;
  static const maxTotal = 9999.0;

  /// Litros y precio: el punto y la coma son siempre decimales
  /// ("1.459" €/L es uno con cuarenta y cinco, no mil cuatrocientos).
  static double? parseAmount(String text) {
    final t = text.replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.').trim();
    if (t.isEmpty || '.'.allMatches(t).length > 1) return null;
    return double.tryParse(t);
  }

  double? get quantityValue => parseAmount(quantity);
  double? get priceValue => parseAmount(price);
  double? get totalValue => MaintenanceEntry.parseCost(total);

  static String? validateQuantity(String text, {String unit = 'L'}) {
    if (text.trim().isEmpty) return null;
    final v = parseAmount(text);
    if (v == null) return 'Escribe un número';
    if (v <= 0 || v > maxQuantity) return 'Entre 0 y 999 $unit';
    return null;
  }

  static String? validatePrice(String text) {
    if (text.trim().isEmpty) return null;
    final v = parseAmount(text);
    if (v == null) return 'Escribe un número';
    if (v <= 0 || v > maxPrice) return 'Entre 0 y 9,999 €';
    return null;
  }

  static String? validateTotal(String text) {
    if (text.trim().isEmpty) return null;
    final v = MaintenanceEntry.parseCost(text);
    if (v == null) return 'Escribe un número';
    if (v <= 0 || v > maxTotal) return 'Entre 0 y 9.999 €';
    return null;
  }

  /// Aviso suave (no impide guardar) si el precio no parece real.
  String? get priceWarning {
    final p = priceValue;
    if (p == null || validatePrice(price) != null) return null;
    final (min, max) = isElectric ? (0.05, 1.2) : (0.6, 3.0);
    if (p < min || p > max) {
      return '¿Seguro? ${Fmt.decimal(p, 3)} $priceUnit es un precio poco habitual.';
    }
    return null;
  }

  /// true si los tres importes están escritos y no cuadran (margen del 2 %
  /// o 10 céntimos, como en SQL: el surtidor redondea).
  bool get amountsMismatch {
    final q = quantityValue, p = priceValue, t = totalValue;
    if (q == null || p == null || t == null) return false;
    final diff = (q * p - t).abs();
    return diff > (t * 0.02 > 0.10 ? t * 0.02 : 0.10);
  }

  // ── Validación completa ──────────────────────────────────────

  String? validate(List<KmLog> logs, {DateTime? today}) {
    final now = today ?? DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month, now.day))) return 'La fecha no puede ser futura.';
    final kmError = MaintenanceEntry.validateKm(km, date, logs);
    if (kmError != null) return kmError;
    final given = [quantity, price, total].where((t) => t.trim().isNotEmpty).length;
    if (given < 2) return 'Escribe al menos dos de: ${isElectric ? 'kWh' : 'litros'}, precio y total.';
    if (validateQuantity(quantity, unit: unit) != null) return 'Revisa los ${isElectric ? 'kWh' : 'litros'}.';
    if (validatePrice(price) != null) return 'Revisa el precio.';
    if (validateTotal(total) != null) return 'Revisa el total.';
    if (amountsMismatch) return 'Cantidad × precio no coincide con el total.';
    if (station.trim().length > 80) return 'El nombre de la gasolinera es demasiado largo.';
    return null;
  }

  /// Parámetros de `register_fuel`. Solo se mandan los importes que ha
  /// escrito el usuario si hay tres: el calculado lo recalcula SQL con
  /// más precisión.
  Map<String, dynamic> toRpcParams(String vehicleId) {
    final d = derived;
    return {
      'p_vehicle_id': vehicleId,
      'p_date': Fmt.isoDate(date),
      'p_km': MaintenanceEntry.parseKm(km),
      'p_liters': d == FuelField.quantity ? null : quantityValue,
      'p_price': d == FuelField.price ? null : priceValue,
      'p_total': d == FuelField.total ? null : totalValue,
      'p_full_tank': fullTank,
      'p_fuel_type': fuelType,
      'p_station': station.trim().isEmpty ? null : station.trim(),
    };
  }

  // ── Ayudas del formulario ────────────────────────────────────

  /// Gasolineras usadas antes en este vehículo, la más reciente primero.
  static List<String> recentStations(List<FuelLog> logs) {
    final sorted = [...logs]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final seen = <String>{};
    final out = <String>[];
    for (final f in sorted) {
      final s = f.station?.trim();
      if (s == null || s.isEmpty) continue;
      if (seen.add(s.toLowerCase())) out.add(s);
    }
    return out;
  }

  /// Consumo del tramo que cierra este repostaje (si es lleno, tiene km y
  /// hay un lleno anterior del mismo tipo de energía), y la media previa.
  ({double value, double? average, String unit})? previewConsumption(List<FuelLog> logs) {
    final k = MaintenanceEntry.parseKm(km);
    final q = quantityValue;
    if (!fullTank || k == null || q == null || q <= 0) return null;
    final sameKind = logs.where((f) => f.isElectric == isElectric).toList();
    final draft = FuelLog(id: '_nuevo', loggedAt: date, km: k, liters: q, fullTank: true, fuelType: fuelType);
    final before = MaintenanceCalculator.consumptionSegments(sameKind);
    final after = MaintenanceCalculator.consumptionSegments([...sameKind, draft]);
    // El nuevo tramo tiene que ser el último (si se registra un repostaje
    // antiguo entre otros, la vista previa no aplica).
    final kms = sameKind.where((f) => f.km != null).map((f) => f.km!);
    if (after.length <= before.length || kms.any((x) => x >= k)) return null;
    final avg = before.isEmpty ? null : before.reduce((a, b) => a + b) / before.length;
    return (value: after.last, average: avg, unit: isElectric ? 'kWh/100' : 'L/100');
  }
}
