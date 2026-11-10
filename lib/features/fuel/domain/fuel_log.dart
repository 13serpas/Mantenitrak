import '../../../shared/utils/json.dart';

class FuelLog {
  const FuelLog({
    required this.id,
    required this.loggedAt,
    this.userId,
    this.km,
    this.liters,
    this.total,
    this.fullTank = true,
    this.pricePerLiter,
    this.fuelType,
    this.station,
  });

  factory FuelLog.fromJson(Map<String, dynamic> j) => FuelLog(
        id: j['id'] as String,
        loggedAt: asDate(j['logged_at']) ?? DateTime(2000),
        userId: asText(j['user_id']),
        km: asInt(j['km']),
        liters: asDouble(j['liters']),
        total: asDouble(j['total']),
        fullTank: j['full_tank'] as bool? ?? true,
        pricePerLiter: asDouble(j['price_per_liter']),
        fuelType: asText(j['fuel_type']),
        station: asText(j['station']),
      );

  final String id;
  final DateTime loggedAt;

  /// Quién lo registró (solo esa persona puede borrarlo). null en la
  /// lista de inicio, que no lo pide.
  final String? userId;
  final int? km;
  final double? liters;
  final double? total;
  final bool fullTank;
  final double? pricePerLiter;
  final String? fuelType;
  final String? station;

  static const electricity = 'Electricidad';

  /// Recarga eléctrica: la cantidad son kWh y el precio €/kWh.
  bool get isElectric => fuelType == electricity;

  /// Repostajes con los que calcular el consumo: los de combustible
  /// líquido si hay alguno (un híbrido enchufable mide L/100 km) y si no,
  /// las recargas (un eléctrico mide kWh/100 km). Nunca mezcla unidades.
  static List<FuelLog> forConsumption(List<FuelLog> logs) {
    final liquid = logs.where((f) => !f.isElectric).toList();
    return liquid.isNotEmpty ? liquid : logs;
  }

  /// Unidad del consumo que sale de [forConsumption].
  static String consumptionUnit(List<FuelLog> logs) =>
      logs.isNotEmpty && logs.every((f) => f.isElectric) ? 'kWh/100' : 'L/100';

  /// Precio por litro guardado o, si falta, deducido del total.
  double? get effectivePricePerLiter {
    if (pricePerLiter != null) return pricePerLiter;
    if (total != null && liters != null && liters! > 0) return total! / liters!;
    return null;
  }
}
