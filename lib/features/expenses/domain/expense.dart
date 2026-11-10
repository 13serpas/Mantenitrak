import '../../../shared/utils/json.dart';

/// Categorías de la tabla `expenses` (CHECK de la migración 002).
enum ExpenseCategory {
  seguro('Seguro', '🛡️'),
  parking('Parking', '🅿️'),
  multa('Multa', '🚨'),
  itv('ITV', '📋'),
  lavado('Lavado', '🧼'),
  peaje('Peaje', '🛣️'),
  impuesto('Impuesto', '🏛️'),
  matriculacion('Matriculación', '📝'),
  reparacion('Reparación', '🔧'),
  accesorio('Accesorio', '🔩'),
  otros('Otros', '💶');

  const ExpenseCategory(this.label, this.icon);
  final String label;
  final String icon;

  static ExpenseCategory parse(String? v) =>
      values.firstWhere((c) => c.name == v, orElse: () => otros);
}

/// Gasto general del vehículo (seguro, parking, multa…). El alta llega en
/// un punto posterior de la hoja de ruta; el detalle ya los muestra.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.paidAt,
    this.description,
    this.userId,
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        category: ExpenseCategory.parse(j['category'] as String?),
        amount: asDouble(j['amount']) ?? 0,
        paidAt: asDate(j['paid_at']) ?? DateTime(2000),
        description: asText(j['description']),
        userId: asText(j['user_id']),
      );

  final String id;
  final ExpenseCategory category;
  final double amount;
  final DateTime paidAt;
  final String? description;
  final String? userId;
}
