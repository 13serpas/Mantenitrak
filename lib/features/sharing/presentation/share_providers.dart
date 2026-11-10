import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/providers/vehicle_detail_provider.dart';
import '../../vehicles/presentation/providers/vehicles_provider.dart';
import '../data/share_repository.dart';
import '../domain/share_code.dart';

/// Código vigente del vehículo (solo se pide si eres el propietario).
final shareInviteProvider = FutureProvider.autoDispose.family<ShareInvite, String>(
  (ref, vehicleId) => ref.watch(shareRepositoryProvider).invite(vehicleId),
);

final vehicleMembersProvider = FutureProvider.autoDispose.family<List<VehicleMember>, String>(
  (ref, vehicleId) => ref.watch(shareRepositoryProvider).members(vehicleId),
);

final shareActionsProvider = Provider<ShareActions>(ShareActions.new);

/// Acciones de compartir. Todas lanzan DataFailure con un mensaje listo.
class ShareActions {
  ShareActions(this._ref);

  final Ref _ref;

  ShareRepository get _repo => _ref.read(shareRepositoryProvider);

  void _refresh(String vehicleId) {
    _ref.invalidate(vehicleMembersProvider(vehicleId));
    _ref.invalidate(vehicleDetailProvider(vehicleId));
    _ref.invalidate(vehiclesProvider);
  }

  Future<void> regenerate(String vehicleId, {int days = 7}) async {
    await _repo.regenerate(vehicleId, days: days);
    _ref.invalidate(shareInviteProvider(vehicleId));
  }

  Future<void> setRole(String vehicleId, String userId, AccessRole role) async {
    await _repo.setRole(vehicleId, userId, role);
    _refresh(vehicleId);
  }

  Future<void> removeMember(String vehicleId, String userId) async {
    await _repo.removeMember(vehicleId, userId);
    _refresh(vehicleId);
  }

  Future<JoinResult> join(String code, AccessRole role) async {
    final r = await _repo.join(code, role);
    _ref.invalidate(vehiclesProvider);
    _ref.invalidate(vehicleDetailProvider(r.vehicleId));
    return r;
  }
}
