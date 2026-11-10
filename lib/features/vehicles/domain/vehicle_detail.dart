import '../../../shared/utils/json.dart';
import '../../expenses/domain/expense.dart';
import 'vehicle.dart';
import 'vehicle_specs.dart';

/// Todo lo que muestra la pantalla de detalle: el vehículo con su historial
/// completo, la ficha técnica y los gastos.
class VehicleDetail {
  const VehicleDetail({
    required this.vehicle,
    this.specs,
    this.expenses = const [],
  });

  factory VehicleDetail.fromJson(Map<String, dynamic> j, {required String currentUserId}) =>
      VehicleDetail(
        vehicle: Vehicle.fromJson(j, currentUserId: currentUserId),
        specs: VehicleSpecs.fromRow(j['vehicle_specs']),
        expenses: asRows(j['expenses']).map(Expense.fromJson).toList()
          ..sort((a, b) => b.paidAt.compareTo(a.paidAt)),
      );

  final Vehicle vehicle;
  final VehicleSpecs? specs;
  final List<Expense> expenses;

  /// Km recorridos desde la primera lectura registrada (para €/km).
  int? get kmTravelled {
    final logs = vehicle.kmLogs;
    if (logs.isEmpty || vehicle.currentKm == null) return null;
    final first = logs.reduce((a, b) => a.loggedAt.isBefore(b.loggedAt) ? a : b);
    final d = vehicle.currentKm! - first.km;
    return d > 0 ? d : null;
  }
}
