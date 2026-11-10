import 'dart:math' as math;

import '../../fuel/domain/fuel_log.dart';
import '../../vehicles/domain/vehicle.dart';
import 'itv_rules.dart';
import 'maintenance_catalog.dart';
import 'maintenance_record.dart';

enum ItemStatus {
  unknown('Sin registrar'),
  ok('Al día'),
  warning('Próximo'),
  danger('Vencido');

  const ItemStatus(this.label);
  final String label;

  bool get needsAttention => this == warning || this == danger;
}

/// Estado de un elemento concreto en un vehículo concreto.
class ItemState {
  const ItemState({
    required this.item,
    required this.status,
    this.progress = 0,
    this.nextDate,
    this.nextKm,
    this.lastRecord,
    this.hint,
  });

  final MaintenanceItem item;
  final ItemStatus status;

  /// Fracción consumida del intervalo: 0 = recién hecho, 1 = vence hoy.
  /// Puede pasar de 1 (vencido hace tiempo); úsalo para ordenar por urgencia.
  final double progress;
  final DateTime? nextDate;
  final int? nextKm;
  final MaintenanceRecord? lastRecord;

  /// Aclaración para el usuario (p. ej. cuándo toca la primera ITV).
  final String? hint;
}

class VehicleHealth {
  const VehicleHealth({
    required this.states,
    required this.averageConsumption,
    this.consumptionUnit = 'L/100',
    required this.annualKm,
    required this.annualKmIsMeasured,
    required this.daysSinceKmLog,
  });

  final List<ItemState> states;

  /// L/100 km. null si aún no hay dos repostajes con depósito lleno.
  final double? averageConsumption;

  /// 'L/100' o 'kWh/100' (eléctricos).
  final String consumptionUnit;
  final int annualKm;

  /// true si sale de lecturas reales del odómetro, false si es la estimación
  /// que dio el usuario al crear el vehículo.
  final bool annualKmIsMeasured;

  /// null = nunca se ha registrado el km.
  final int? daysSinceKmLog;

  int count(ItemStatus s) => states.where((e) => e.status == s).length;
  int get danger => count(ItemStatus.danger);
  int get warning => count(ItemStatus.warning);
  int get ok => count(ItemStatus.ok);

  /// % de elementos registrados que están al día. null si no hay ninguno.
  int? get healthPercent {
    final known = states.where((s) => s.status != ItemStatus.unknown).length;
    if (known == 0) return null;
    return (ok / known * 100).round();
  }

  /// Vencidos y próximos, del más urgente al menos.
  List<ItemState> get alerts =>
      states.where((s) => s.status.needsAttention).toList()
        ..sort((a, b) => b.progress.compareTo(a.progress));

  bool get kmUpdateDue => daysSinceKmLog == null || daysSinceKmLog! > 30;
}

abstract final class MaintenanceCalculator {
  static const warningThreshold = 0.8;

  static VehicleHealth healthOf(Vehicle v, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final plan = MaintenanceCatalog.planFor(v);
    final (annual, measured) = annualKm(v);
    return VehicleHealth(
      states: [for (final item in plan) stateOf(item, v, today)],
      averageConsumption: averageConsumption(v.fuelLogs),
      consumptionUnit: FuelLog.consumptionUnit(v.fuelLogs),
      annualKm: annual,
      annualKmIsMeasured: measured,
      daysSinceKmLog: daysSinceKmLog(v, today),
    );
  }

  static ItemState stateOf(MaintenanceItem item, Vehicle v, DateTime now) {
    MaintenanceRecord? last;
    for (final r in v.maintenance) {
      if (r.itemId != item.id) continue;
      if (last == null || r.performedAt.isAfter(last.performedAt)) last = r;
    }
    if (item.id == 'itv') return _itvState(item, v, last, now);
    if (last == null) return ItemState(item: item, status: ItemStatus.unknown);

    double? byTime;
    double? byKm;
    DateTime? nextDate;
    int? nextKm;

    if (item.intervalMonths != null) {
      nextDate = addMonths(last.performedAt, item.intervalMonths!);
      final total = nextDate.difference(last.performedAt).inDays;
      final elapsed = _dateOnly(now).difference(last.performedAt).inDays;
      byTime = total > 0 ? elapsed / total : 1;
    }
    if (item.intervalKm != null && last.km != null) {
      nextKm = last.km! + item.intervalKm!;
      if (v.currentKm != null) byKm = (v.currentKm! - last.km!) / item.intervalKm!;
    }

    // Elemento solo por km sin km registrados: no podemos saber nada.
    if (byTime == null && byKm == null) {
      return ItemState(item: item, status: ItemStatus.unknown, nextKm: nextKm, lastRecord: last);
    }

    final progress = math.max(byTime ?? 0, byKm ?? 0).clamp(0.0, double.infinity);
    final status = progress >= 1
        ? ItemStatus.danger
        : progress >= warningThreshold
            ? ItemStatus.warning
            : ItemStatus.ok;

    return ItemState(
      item: item,
      status: status,
      progress: progress.toDouble(),
      nextDate: nextDate,
      nextKm: nextKm,
      lastRecord: last,
    );
  }

  /// Consumo medio por el método de "lleno a lleno": suma los litros de
  /// todos los repostajes (incluidos los parciales) entre dos llenos y los
  /// divide por los km recorridos entre esos dos llenos.
  static double? averageConsumption(List<FuelLog> logs) {
    final sorted = FuelLog.forConsumption(logs).where((f) => f.km != null && f.liters != null).toList()
      ..sort((a, b) => a.km!.compareTo(b.km!));

    int? lastFullKm;
    var pendingLiters = 0.0;
    var totalLiters = 0.0;
    var totalKm = 0;

    for (final f in sorted) {
      if (lastFullKm == null) {
        if (f.fullTank) lastFullKm = f.km;
        continue;
      }
      pendingLiters += f.liters!;
      if (f.fullTank) {
        final distance = f.km! - lastFullKm;
        if (distance > 0) {
          totalLiters += pendingLiters;
          totalKm += distance;
        }
        pendingLiters = 0;
        lastFullKm = f.km;
      }
    }
    return totalKm > 0 ? totalLiters / totalKm * 100 : null;
  }

  /// La ITV no tiene un intervalo fijo: depende del tipo y de la edad del
  /// vehículo (un coche de más de 10 años la pasa cada año).
  static ItemState _itvState(MaintenanceItem item, Vehicle v, MaintenanceRecord? last, DateTime now) {
    final today = _dateOnly(now);
    final rule = ItvRules.describe(v.type);
    if (last == null) {
      final first = ItvRules.firstItvYear(v);
      // Aún no le toca la primera: está al día aunque no haya registro.
      if (first != null && today.year < first) {
        final span = ItvRules.firstAfterYears(v.type);
        final elapsed = (today.year - v.year).clamp(0, span);
        return ItemState(
          item: item,
          status: ItemStatus.ok,
          progress: span == 0 ? 0 : elapsed / span * 0.5,
          hint: 'Primera ITV en $first (${ItvRules.firstAfterYears(v.type)} años desde la matriculación). $rule',
        );
      }
      return ItemState(item: item, status: ItemStatus.unknown, hint: rule);
    }
    final age = ItvRules.ageAt(v, last.performedAt);
    final months = (age == null ? null : ItvRules.intervalMonths(v.type, age)) ?? item.intervalMonths ?? 24;
    final nextDate = addMonths(last.performedAt, months);
    final total = nextDate.difference(last.performedAt).inDays;
    final elapsed = today.difference(last.performedAt).inDays;
    final progress = (total > 0 ? elapsed / total : 1.0).clamp(0.0, double.infinity).toDouble();
    final every = months % 12 == 0 ? (months == 12 ? 'cada año' : 'cada ${months ~/ 12} años') : 'cada $months meses';
    return ItemState(
      item: item,
      status: progress >= 1
          ? ItemStatus.danger
          : progress >= warningThreshold
              ? ItemStatus.warning
              : ItemStatus.ok,
      progress: progress,
      nextDate: nextDate,
      lastRecord: last,
      hint: age == null ? rule : 'Con ${age == 1 ? '1 año' : '$age años'} le toca $every. $rule',
    );
  }

  /// Consumo (L/100 km, o kWh/100 km en eléctricos) de cada tramo entre dos depósitos llenos, del más
  /// antiguo al más reciente.
  static List<double> consumptionSegments(List<FuelLog> logs) {
    final sorted = FuelLog.forConsumption(logs).where((f) => f.km != null && f.liters != null).toList()
      ..sort((a, b) => a.km!.compareTo(b.km!));
    final out = <double>[];
    int? lastFullKm;
    var pending = 0.0;
    for (final f in sorted) {
      if (lastFullKm == null) {
        if (f.fullTank) lastFullKm = f.km;
        continue;
      }
      pending += f.liters!;
      if (f.fullTank) {
        final distance = f.km! - lastFullKm;
        if (distance > 0) out.add(pending / distance * 100);
        pending = 0;
        lastFullKm = f.km;
      }
    }
    return out;
  }

  /// Aviso si el último tramo gasta claramente más que la media de los
  /// anteriores (hacen falta al menos 2 tramos previos para comparar).
  static ({double last, double average, int percentAbove})? consumptionIncrease(
    List<FuelLog> logs, {
    double threshold = 0.15,
  }) {
    final seg = consumptionSegments(logs);
    if (seg.length < 3) return null;
    final previous = seg.sublist(0, seg.length - 1);
    final avg = previous.reduce((a, b) => a + b) / previous.length;
    final last = seg.last;
    if (avg <= 0 || last <= avg * (1 + threshold)) return null;
    return (last: last, average: avg, percentAbove: ((last / avg - 1) * 100).round());
  }

  /// Km/año reales a partir de lecturas que abarquen al menos 30 días;
  /// si no, la estimación del usuario (o 12.000).
  static (int, bool) annualKm(Vehicle v) {
    if (v.kmLogs.length >= 2) {
      final logs = [...v.kmLogs]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      final days = logs.last.loggedAt.difference(logs.first.loggedAt).inDays;
      final km = logs.last.km - logs.first.km;
      if (days >= 30 && km >= 0) return ((km / days * 365).round(), true);
    }
    return (v.annualKm ?? 12000, false);
  }

  static int? daysSinceKmLog(Vehicle v, DateTime now) {
    if (v.kmLogs.isEmpty) return null;
    final latest = v.kmLogs.map((l) => l.loggedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return _dateOnly(now).difference(latest).inDays;
  }

  /// Suma meses sin desbordar: 31 ene + 1 mes = 28/29 feb (no 3 mar).
  static DateTime addMonths(DateTime d, int months) {
    final target = DateTime(d.year, d.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, math.min(d.day, lastDay));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
