import '../../vehicles/domain/vehicle.dart';

/// Un elemento revisable y cada cuánto toca (por km, por meses o ambos;
/// gana lo que llegue antes).
class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.intervalKm,
    this.intervalMonths,
  });

  final String id;
  final String name;
  final String icon;
  final String category;
  final int? intervalKm;
  final int? intervalMonths;

  MaintenanceItem withIntervals({int? km, int? months}) => MaintenanceItem(
        id: id,
        name: name,
        icon: icon,
        category: category,
        intervalKm: km ?? intervalKm,
        intervalMonths: months ?? intervalMonths,
      );
}

/// Planes de mantenimiento por tipo de vehículo.
///
/// ⚠️ Los `id` se guardan en `maintenance_records.item_id`: NO cambiarlos.
/// Para renombrar uno, añade el antiguo a [_legacyIds].
abstract final class MaintenanceCatalog {
  // ── Coche (también furgoneta, 4x4, caravana y "otro") ────────
  static const _car = [
    MaintenanceItem(id: 'aceite', name: 'Aceite del motor', icon: '🛢️', category: 'Motor', intervalKm: 10000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aceite', name: 'Filtro de aceite', icon: '🔵', category: 'Motor', intervalKm: 10000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aire', name: 'Filtro de aire', icon: '💨', category: 'Motor', intervalKm: 20000, intervalMonths: 24),
    MaintenanceItem(id: 'filtro_combustible', name: 'Filtro de combustible', icon: '⛽', category: 'Motor', intervalKm: 30000, intervalMonths: 36),
    MaintenanceItem(id: 'bujias', name: 'Bujías', icon: '⚡', category: 'Motor', intervalKm: 30000),
    MaintenanceItem(id: 'correa_distribucion', name: 'Correa de distribución', icon: '🔧', category: 'Motor', intervalKm: 80000, intervalMonths: 60),
    MaintenanceItem(id: 'refrigerante', name: 'Refrigerante', icon: '🧊', category: 'Motor', intervalKm: 60000, intervalMonths: 48),
    MaintenanceItem(id: 'filtro_habitaculo', name: 'Filtro de habitáculo', icon: '🌬️', category: 'Habitáculo', intervalKm: 15000, intervalMonths: 12),
    MaintenanceItem(id: 'frenos_delanteros', name: 'Pastillas delanteras', icon: '🔴', category: 'Frenos', intervalKm: 30000),
    MaintenanceItem(id: 'frenos_traseros', name: 'Pastillas traseras', icon: '🔴', category: 'Frenos', intervalKm: 40000),
    MaintenanceItem(id: 'discos_delanteros', name: 'Discos delanteros', icon: '⚙️', category: 'Frenos', intervalKm: 60000),
    MaintenanceItem(id: 'liquido_frenos', name: 'Líquido de frenos', icon: '💧', category: 'Frenos', intervalMonths: 24),
    MaintenanceItem(id: 'neumaticos', name: 'Neumáticos', icon: '🔘', category: 'Ruedas', intervalKm: 40000, intervalMonths: 48),
    MaintenanceItem(id: 'bateria', name: 'Batería', icon: '🔋', category: 'Eléctrico', intervalMonths: 48),
    MaintenanceItem(id: 'itv', name: 'ITV', icon: '📋', category: 'Legal', intervalMonths: 24),
  ];

  // ── Moto (también quad) ──────────────────────────────────────
  static const _moto = [
    MaintenanceItem(id: 'aceite', name: 'Aceite del motor', icon: '🛢️', category: 'Motor', intervalKm: 6000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aceite', name: 'Filtro de aceite', icon: '🔵', category: 'Motor', intervalKm: 6000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aire', name: 'Filtro de aire', icon: '💨', category: 'Motor', intervalKm: 12000, intervalMonths: 12),
    MaintenanceItem(id: 'bujias', name: 'Bujías', icon: '⚡', category: 'Motor', intervalKm: 12000),
    MaintenanceItem(id: 'cadena_lubricado', name: 'Engrasar cadena', icon: '⛓️', category: 'Transmisión', intervalKm: 500),
    MaintenanceItem(id: 'cadena_cambio', name: 'Kit de arrastre', icon: '⛓️', category: 'Transmisión', intervalKm: 20000),
    MaintenanceItem(id: 'frenos_delanteros', name: 'Pastillas delanteras', icon: '🔴', category: 'Frenos', intervalKm: 20000),
    MaintenanceItem(id: 'frenos_traseros', name: 'Pastillas traseras', icon: '🔴', category: 'Frenos', intervalKm: 15000),
    MaintenanceItem(id: 'liquido_frenos', name: 'Líquido de frenos', icon: '💧', category: 'Frenos', intervalMonths: 24),
    MaintenanceItem(id: 'neumaticos', name: 'Neumáticos', icon: '🔘', category: 'Ruedas', intervalKm: 15000, intervalMonths: 36),
    MaintenanceItem(id: 'bateria', name: 'Batería', icon: '🔋', category: 'Eléctrico', intervalMonths: 36),
    MaintenanceItem(id: 'itv', name: 'ITV', icon: '📋', category: 'Legal', intervalMonths: 24),
  ];

  // ── Camión (también autobús) ─────────────────────────────────
  static const _truck = [
    MaintenanceItem(id: 'aceite', name: 'Aceite del motor', icon: '🛢️', category: 'Motor', intervalKm: 40000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aceite', name: 'Filtro de aceite', icon: '🔵', category: 'Motor', intervalKm: 40000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aire', name: 'Filtro de aire', icon: '💨', category: 'Motor', intervalKm: 80000, intervalMonths: 12),
    MaintenanceItem(id: 'filtro_combustible', name: 'Filtro de combustible', icon: '⛽', category: 'Motor', intervalKm: 40000, intervalMonths: 12),
    MaintenanceItem(id: 'refrigerante', name: 'Refrigerante', icon: '🧊', category: 'Motor', intervalKm: 100000, intervalMonths: 36),
    MaintenanceItem(id: 'correa_distribucion', name: 'Correa de distribución', icon: '🔧', category: 'Motor', intervalKm: 200000, intervalMonths: 60),
    MaintenanceItem(id: 'frenos', name: 'Zapatas de freno', icon: '🔴', category: 'Frenos', intervalKm: 80000),
    MaintenanceItem(id: 'liquido_frenos', name: 'Líquido de frenos', icon: '💧', category: 'Frenos', intervalMonths: 24),
    MaintenanceItem(id: 'neumaticos', name: 'Neumáticos', icon: '🔘', category: 'Ruedas', intervalKm: 120000, intervalMonths: 60),
    MaintenanceItem(id: 'bateria', name: 'Baterías', icon: '🔋', category: 'Eléctrico', intervalMonths: 36),
    MaintenanceItem(id: 'tacografo', name: 'Revisión del tacógrafo', icon: '🗂️', category: 'Legal', intervalMonths: 24),
    MaintenanceItem(id: 'itv', name: 'ITV', icon: '📋', category: 'Legal', intervalMonths: 12),
  ];

  // ── Barco: plan básico por tiempo (pendiente de afinar) ──────
  static const _boat = [
    MaintenanceItem(id: 'aceite', name: 'Aceite del motor', icon: '🛢️', category: 'Motor', intervalMonths: 12),
    MaintenanceItem(id: 'filtro_aceite', name: 'Filtro de aceite', icon: '🔵', category: 'Motor', intervalMonths: 12),
    MaintenanceItem(id: 'filtro_combustible', name: 'Filtro de combustible', icon: '⛽', category: 'Motor', intervalMonths: 24),
    MaintenanceItem(id: 'anodos', name: 'Ánodos de sacrificio', icon: '🔩', category: 'Casco', intervalMonths: 12),
    MaintenanceItem(id: 'bateria', name: 'Batería', icon: '🔋', category: 'Eléctrico', intervalMonths: 36),
    MaintenanceItem(id: 'revision_general', name: 'Revisión general', icon: '🧰', category: 'General', intervalMonths: 12),
  ];

  /// IDs que usaba el prototipo → ID actual.
  static const _legacyIds = {
    'frenos_del': 'frenos_delanteros',
    'frenos_delan': 'frenos_delanteros',
    'frenos_tra': 'frenos_traseros',
    'frenos_tras': 'frenos_traseros',
    'discos_del': 'discos_delanteros',
    'liq_frenos': 'liquido_frenos',
    'correa': 'correa_distribucion',
    'cadena_lub': 'cadena_lubricado',
    'cadena_cam': 'cadena_cambio',
    'filtro_comb': 'filtro_combustible',
  };

  static String normalizeId(String id) => _legacyIds[id] ?? id;

  static List<MaintenanceItem> basePlan(VehicleType type) => switch (type) {
        VehicleType.moto || VehicleType.quad => _moto,
        VehicleType.camion || VehicleType.autobus => _truck,
        VehicleType.barco => _boat,
        _ => _car,
      };

  /// Plan ajustado a combustible, uso y zona del vehículo.
  static List<MaintenanceItem> planFor(Vehicle v) {
    final fuel = (v.fuelType ?? '').toLowerCase();
    final usage = (v.usage ?? '').toLowerCase();
    final isElectric = fuel.contains('eléctric') || fuel.contains('electric');
    final isDiesel = fuel.contains('diés') || fuel.contains('dies');
    final isHybrid = fuel.contains('híbrid') || fuel.contains('hibrid');
    final isLpg = fuel.contains('glp');

    // Elementos que no existen según el motor.
    const noElectric = {'aceite', 'filtro_aceite', 'filtro_combustible', 'bujias', 'correa_distribucion'};
    const noDiesel = {'bujias'}; // los diésel llevan calentadores, no bujías

    return [
      for (final item in basePlan(v.type))
        if (!(isElectric && noElectric.contains(item.id)) &&
            !(isDiesel && noDiesel.contains(item.id)))
          _adjust(item, v, usage: usage, hybrid: isHybrid, lpg: isLpg),
    ];
  }

  static const _zoneTyreFactor = {
    'interior': 1.0,
    'costa': 0.82,
    'montana': 0.78,
    'mixto': 0.92,
    'norte': 0.85,
  };

  static MaintenanceItem _adjust(
    MaintenanceItem item,
    Vehicle v, {
    required String usage,
    required bool hybrid,
    required bool lpg,
  }) {
    final hardUse = usage == 'ciudad' || usage == 'profesional';

    if ((item.id == 'aceite' || item.id == 'filtro_aceite') && item.intervalKm != null) {
      var f = 1.0;
      if (hybrid) f *= 1.2;
      if (lpg) f *= 0.8;
      if (hardUse) f *= 0.85;
      return item.withIntervals(km: _round500(item.intervalKm! * f));
    }

    if (item.id == 'neumaticos' && item.intervalKm != null) {
      var f = _zoneTyreFactor[v.zone] ?? 1.0;
      if (usage == 'carretera') f *= 0.9;
      if (usage == 'profesional') f *= 0.75;
      // En zonas duras (costa, montaña, norte) el caucho también envejece antes.
      final zoneFactor = _zoneTyreFactor[v.zone] ?? 1.0;
      final months = item.intervalMonths == null || zoneFactor >= 0.85
          ? item.intervalMonths
          : (item.intervalMonths! * 0.875).round();
      return item.withIntervals(km: _round500(item.intervalKm! * f), months: months);
    }

    return item;
  }

  static int _round500(double km) => (km / 500).round() * 500;
}
