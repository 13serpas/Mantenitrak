import '../../vehicles/domain/vehicle.dart';

/// Precio orientativo en taller (pieza + mano de obra, IVA incluido) de
/// cada trabajo en España. Solo se usa para REPARTIR un coste total entre
/// varios trabajos cuando no se sabe cuánto costó cada uno: importa la
/// proporción entre trabajos, no el importe exacto.
///
/// Fuentes (turismo, medias nacionales 2025-2026): cambio de aceite y
/// filtro ~90 €, filtro de aire ~33 €, pastillas delanteras ~115 €,
/// 4 neumáticos ~454 €, kit de distribución ~415 € (Tallerator vía
/// Autofácil); ITV ~39-46 € + 4,18 € de tasa (FACUA 2026). El resto, y las tablas de
/// motos, camiones y barcos, son estimaciones propias a partir de esas.
/// Ver docs/PRECIOS_REFERENCIA.md.
abstract final class ReferencePrices {
  static const _car = {
    'aceite': 75.0,
    'filtro_aceite': 15.0,
    'filtro_aire': 33.0,
    'filtro_combustible': 60.0,
    'bujias': 90.0,
    'correa_distribucion': 415.0,
    'refrigerante': 70.0,
    'filtro_habitaculo': 30.0,
    'frenos_delanteros': 115.0,
    'frenos_traseros': 100.0,
    'discos_delanteros': 230.0,
    'liquido_frenos': 50.0,
    'neumaticos': 454.0,
    'bateria': 130.0,
    'itv': 43.0,
  };

  static const _moto = {
    'aceite': 55.0,
    'filtro_aceite': 15.0,
    'filtro_aire': 30.0,
    'bujias': 45.0,
    'cadena_lubricado': 10.0,
    'cadena_cambio': 190.0,
    'frenos_delanteros': 70.0,
    'frenos_traseros': 60.0,
    'liquido_frenos': 40.0,
    'neumaticos': 260.0,
    'bateria': 70.0,
    'itv': 30.0,
  };

  static const _truck = {
    'aceite': 380.0,
    'filtro_aceite': 70.0,
    'filtro_aire': 120.0,
    'filtro_combustible': 90.0,
    'refrigerante': 250.0,
    'correa_distribucion': 900.0,
    'frenos': 600.0,
    'liquido_frenos': 120.0,
    'neumaticos': 2600.0,
    'bateria': 450.0,
    'tacografo': 120.0,
    'itv': 110.0,
  };

  static const _boat = {
    'aceite': 120.0,
    'filtro_aceite': 25.0,
    'filtro_combustible': 50.0,
    'anodos': 110.0,
    'bateria': 180.0,
    'revision_general': 300.0,
  };

  /// Furgonetas, 4x4 y autocaravanas usan la tabla de turismo, algo más cara.
  static double _factor(VehicleType t) => switch (t) {
        VehicleType.furgoneta || VehicleType.todoterreno => 1.15,
        VehicleType.caravana => 1.25,
        VehicleType.autobus => 1.2,
        _ => 1.0,
      };

  static Map<String, double> _table(VehicleType t) => switch (t) {
        VehicleType.moto || VehicleType.quad => _moto,
        VehicleType.camion || VehicleType.autobus => _truck,
        VehicleType.barco => _boat,
        _ => _car,
      };

  /// Precio de referencia o null si el trabajo no está en la tabla.
  static double? of(String itemId, VehicleType type) {
    final base = _table(type)[itemId];
    return base == null ? null : base * _factor(type);
  }

  /// Reparte [total] entre los trabajos en proporción a su precio de
  /// referencia. Los trabajos sin referencia ("otro") pesan como la
  /// mediana de los demás. Devuelve importes con céntimos que suman
  /// exactamente [total]. Clave: la de cada línea.
  static Map<String, double> split(
    double total,
    List<({String key, String itemId})> lines,
    VehicleType type,
  ) {
    if (lines.isEmpty) return const {};
    final known = [for (final l in lines) of(l.itemId, type)].whereType<double>().toList()..sort();
    final fallback = known.isEmpty ? 100.0 : known[known.length ~/ 2];
    final weights = {for (final l in lines) l.key: of(l.itemId, type) ?? fallback};
    final sum = weights.values.fold<double>(0, (a, b) => a + b);

    final totalCents = (total * 100).round();
    final cents = {for (final e in weights.entries) e.key: (totalCents * e.value / sum).floor()};
    // Los céntimos que sobran del redondeo van al trabajo más caro.
    final rest = totalCents - cents.values.fold<int>(0, (a, b) => a + b);
    final biggest = weights.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    cents[biggest] = cents[biggest]! + rest;
    return {for (final e in cents.entries) e.key: e.value / 100};
  }
}
