import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import 'vehicle_detail_provider.dart';

/// Lista de vehículos del usuario. Se recarga sola al cambiar de cuenta.
final vehiclesProvider =
    AsyncNotifierProvider<VehiclesNotifier, List<Vehicle>>(VehiclesNotifier.new);

class VehiclesNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.watch(vehicleRepositoryProvider).fetchMine(userId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Lanza [DataFailure] si falla; la lista se recarga si va bien.
  Future<void> logKm(String vehicleId, int km) async {
    await ref.read(vehicleRepositoryProvider).logKm(vehicleId, km);
    ref.invalidate(vehicleDetailProvider(vehicleId));
    await refresh();
  }
}

/// Una alerta de la pantalla de inicio: qué vehículo y qué elemento.
typedef VehicleAlert = ({Vehicle vehicle, ItemState state});

/// Todo lo que la pantalla de inicio calcula a partir de la lista, una vez.
class HomeOverview {
  HomeOverview(this.vehicles, {DateTime? now})
      : health = {
          for (final v in vehicles) v.id: MaintenanceCalculator.healthOf(v, now: now),
        };

  final List<Vehicle> vehicles;
  final Map<String, VehicleHealth> health;

  VehicleHealth healthOf(Vehicle v) => health[v.id]!;

  /// Todas las alertas, de la más urgente a la menos.
  List<VehicleAlert> get alerts => [
        for (final v in vehicles)
          for (final s in health[v.id]!.alerts) (vehicle: v, state: s),
      ]..sort((a, b) => b.state.progress.compareTo(a.state.progress));

  List<Vehicle> get kmUpdateDue =>
      vehicles.where((v) => health[v.id]!.kmUpdateDue).toList();
}

/// Modo taller (recuperado del prototipo): muestra solo los vehículos que
/// gestionas como taller, ordenados por urgencia.
final workshopModeProvider = StateProvider<bool>((_) => false);

final homeOverviewProvider = Provider<AsyncValue<HomeOverview>>(
  (ref) => ref.watch(vehiclesProvider).whenData(HomeOverview.new),
);
