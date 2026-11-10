import '../../fuel/domain/fuel_log.dart';
import '../../maintenance/domain/maintenance_record.dart';
import 'expense.dart';

/// Periodos del resumen de gastos.
enum CostPeriod {
  month('Este mes', 'este mes'),
  year('Este año', 'este año'),
  last12('12 meses', 'en los últimos 12 meses'),
  all('Todo', 'desde el alta');

  const CostPeriod(this.label, this.phrase);
  final String label;

  /// Para frases: "Gasto total este mes".
  final String phrase;

  /// Primer día incluido (null = sin límite).
  DateTime? start(DateTime now) => switch (this) {
        CostPeriod.month => DateTime(now.year, now.month, 1),
        CostPeriod.year => DateTime(now.year, 1, 1),
        CostPeriod.last12 => DateTime(now.year, now.month - 11, 1),
        CostPeriod.all => null,
      };
}

/// Total de un mes para el gráfico de barras.
class MonthCost {
  const MonthCost(this.month, {this.maintenance = 0, this.fuel = 0, this.other = 0});

  /// Día 1 del mes.
  final DateTime month;
  final double maintenance;
  final double fuel;
  final double other;

  double get total => maintenance + fuel + other;
}

/// Resumen de gastos calculado en la app a partir de lo que ya trae el
/// detalle (mantenimientos, repostajes y gastos). Sustituye a la función
/// `get_expense_summary` del prototipo, que tenía varios fallos de fechas.
class CostSummary {
  CostSummary._({
    required this.period,
    required this.maintenance,
    required this.fuel,
    required this.byCategory,
    required this.months,
    required this.costPerKm,
  });

  factory CostSummary.compute({
    required CostPeriod period,
    required List<MaintenanceRecord> maintenance,
    required List<FuelLog> fuel,
    required List<Expense> expenses,
    int? kmTravelled,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final from = period.start(today);
    bool inPeriod(DateTime d) => (from == null || !d.isBefore(from)) && !d.isAfter(today);

    final maint = maintenance.where((r) => inPeriod(r.performedAt)).fold<double>(0, (s, r) => s + (r.cost ?? 0));
    final fuelTotal = fuel.where((f) => inPeriod(f.loggedAt)).fold<double>(0, (s, f) => s + (f.total ?? 0));
    final byCategory = <ExpenseCategory, double>{};
    for (final e in expenses.where((e) => inPeriod(e.paidAt))) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    // Gráfico: siempre los últimos 12 meses, sea cual sea el periodo.
    final months = <MonthCost>[];
    for (var i = 11; i >= 0; i--) {
      final m = DateTime(today.year, today.month - i, 1);
      bool same(DateTime d) => d.year == m.year && d.month == m.month;
      months.add(MonthCost(
        m,
        maintenance: maintenance.where((r) => same(r.performedAt)).fold<double>(0, (s, r) => s + (r.cost ?? 0)),
        fuel: fuel.where((f) => same(f.loggedAt)).fold<double>(0, (s, f) => s + (f.total ?? 0)),
        other: expenses.where((e) => same(e.paidAt)).fold<double>(0, (s, e) => s + e.amount),
      ));
    }

    final otherTotal = byCategory.values.fold<double>(0, (s, v) => s + v);
    final total = maint + fuelTotal + otherTotal;
    // €/km solo tiene sentido con todo el histórico y algo de distancia.
    final perKm = period == CostPeriod.all && kmTravelled != null && kmTravelled >= 100 && total > 0
        ? total / kmTravelled
        : null;

    return CostSummary._(
      period: period,
      maintenance: maint,
      fuel: fuelTotal,
      byCategory: byCategory,
      months: months,
      costPerKm: perKm,
    );
  }

  final CostPeriod period;
  final double maintenance;
  final double fuel;
  final Map<ExpenseCategory, double> byCategory;
  final List<MonthCost> months;

  /// €/km de todo el histórico. null si no hay datos suficientes.
  final double? costPerKm;

  double get other => byCategory.values.fold<double>(0, (s, v) => s + v);
  double get total => maintenance + fuel + other;
  bool get isEmpty => total == 0;

  /// Categorías de "otros gastos", de mayor a menor importe.
  List<MapEntry<ExpenseCategory, double>> get categoriesSorted =>
      byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
