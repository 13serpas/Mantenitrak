import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../fuel/data/fuel_repository.dart';
import '../../../fuel/domain/fuel_entry.dart';
import '../../../fuel/domain/fuel_log.dart';
import '../../../maintenance/data/maintenance_repository.dart';
import '../../../maintenance/domain/maintenance_entry.dart';
import '../../../maintenance/domain/maintenance_record.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_detail.dart';
import '../../domain/vehicle_draft.dart';
import '../../domain/vehicle_specs.dart';
import 'vehicles_provider.dart';

/// Detalle de un vehículo. null = no existe o ya no tienes acceso.
final vehicleDetailProvider =
    FutureProvider.autoDispose.family<VehicleDetail?, String>((ref, vehicleId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(vehicleRepositoryProvider).fetchDetail(vehicleId, userId);
});

/// Acciones del detalle. Tras cada cambio recarga el detalle y la lista de
/// inicio para que las dos pantallas muestren lo mismo.
final vehicleActionsProvider = Provider<VehicleActions>(VehicleActions.new);

class VehicleActions {
  VehicleActions(this._ref);

  final Ref _ref;

  VehicleRepository get _repo => _ref.read(vehicleRepositoryProvider);

  void _refresh(String vehicleId) {
    _ref.invalidate(vehicleDetailProvider(vehicleId));
    _ref.invalidate(vehiclesProvider);
  }

  /// Todas lanzan [DataFailure] con un mensaje listo para mostrar.
  Future<void> update(String vehicleId, VehicleDraft draft) async {
    await _repo.updateVehicle(vehicleId, draft);
    _refresh(vehicleId);
  }

  Future<void> saveSpecs(String vehicleId, VehicleSpecs? specs) async {
    await _repo.saveSpecs(vehicleId, specs);
    _refresh(vehicleId);
  }

  /// Registra uno o varios trabajos (punto 5). Devuelve cuántos.
  Future<int> registerMaintenance(
    String vehicleId,
    MaintenanceEntry entry, {
    required VehicleType type,
    void Function(int done, int total)? onProgress,
  }) async {
    final n = await _ref
        .read(maintenanceRepositoryProvider)
        .register(vehicleId, entry, type: type, onProgress: onProgress);
    _refresh(vehicleId);
    return n;
  }

  Future<void> deleteRecord(String vehicleId, MaintenanceRecord record) async {
    await _repo.deleteMaintenanceRecord(record.id);
    // Las fotos no se borran solas con la fila.
    await _ref.read(maintenanceRepositoryProvider).removePhotos(record.storagePhotos);
    _refresh(vehicleId);
  }

  /// Registra un repostaje o una recarga (punto 6).
  Future<void> registerFuel(String vehicleId, FuelEntry entry) async {
    await _ref.read(fuelRepositoryProvider).register(vehicleId, entry);
    _refresh(vehicleId);
  }

  Future<void> deleteFuelLog(String vehicleId, FuelLog log) async {
    await _repo.deleteFuelLog(log.id);
    _refresh(vehicleId);
  }

  /// Propietario: borra el vehículo. Compartido: deja de verlo.
  Future<void> removeVehicle(String vehicleId, {required bool isOwner}) async {
    if (isOwner) {
      // Primero las fotos: después de borrar el vehículo, Storage ya no
      // reconocería al propietario.
      await _ref.read(maintenanceRepositoryProvider).removeVehicleFolder(vehicleId);
      await _repo.deleteVehicle(vehicleId);
    } else {
      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) throw const DataFailure('Tu sesión ha caducado. Vuelve a iniciar sesión.');
      await _repo.leaveVehicle(vehicleId, userId);
    }
    _ref.invalidate(vehiclesProvider);
  }
}

/// URLs temporales de fotos privadas. La clave son las rutas unidas por
/// saltos de línea (una clave String para que la caché funcione).
final photoUrlsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>(
  (ref, joinedPaths) => ref
      .watch(maintenanceRepositoryProvider)
      .photoUrls(joinedPaths.split('\n').where((p) => p.isNotEmpty).toList()),
);
