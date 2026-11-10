import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../vehicles/domain/vehicle.dart';
import '../domain/share_code.dart';

final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => ShareRepository(ref.watch(supabaseClientProvider)),
);

/// Compartir vehículos (punto 7, migración 008). Todo pasa por funciones
/// SQL: el código no se puede leer de ninguna tabla.
class ShareRepository {
  ShareRepository(this._db);

  final SupabaseClient _db;

  static Map<String, dynamic> _first(dynamic rows) {
    final list = rows as List;
    if (list.isEmpty) throw const DataFailure('No se ha recibido respuesta. Inténtalo de nuevo.');
    return Map<String, dynamic>.from(list.first as Map);
  }

  /// Código vigente; si no hay o ha caducado, se crea uno (solo propietario).
  Future<ShareInvite> invite(String vehicleId) => guardData(() async {
        final rows = await _db.rpc('get_share_invite', params: {'p_vehicle_id': vehicleId});
        return ShareInvite.fromJson(_first(rows));
      });

  /// Código nuevo: el anterior deja de valer.
  Future<ShareInvite> regenerate(String vehicleId, {int days = 7}) => guardData(() async {
        final rows = await _db.rpc('regenerate_share_code', params: {'p_vehicle_id': vehicleId, 'p_days': days});
        return ShareInvite.fromJson(_first(rows));
      });

  Future<List<VehicleMember>> members(String vehicleId) => guardData(() async {
        final rows = await _db.rpc('vehicle_members', params: {'p_vehicle_id': vehicleId});
        return (rows as List).map((r) => VehicleMember.fromJson(Map<String, dynamic>.from(r as Map))).toList();
      });

  Future<void> setRole(String vehicleId, String userId, AccessRole role) => guardData(() => _db.rpc(
        'set_member_role',
        params: {'p_vehicle_id': vehicleId, 'p_user_id': userId, 'p_role': role.name},
      ));

  /// Quita el acceso a otra persona (solo el propietario, por RLS).
  Future<void> removeMember(String vehicleId, String userId) => guardData(() async {
        final deleted = await _db
            .from('shared_vehicles')
            .delete()
            .eq('vehicle_id', vehicleId)
            .eq('user_id', userId)
            .select('user_id');
        if (deleted.isEmpty) throw const DataFailure('Esa persona ya no tenía acceso.');
      });

  /// Se une a un vehículo. Un código inexistente o caducado no llega como
  /// error SQL sino en la columna `error` (así cuenta para el límite de
  /// intentos).
  Future<JoinResult> join(String code, AccessRole role) => guardData(() async {
        final rows = await _db.rpc('join_vehicle_by_code', params: {
          'p_code': ShareCode.normalize(code),
          'p_role': role == AccessRole.owner ? AccessRole.regular.name : role.name,
        });
        final r = _first(rows);
        final error = r['error'] as String?;
        if (error != null) throw DataFailure(error);
        return JoinResult(
          vehicleId: r['vehicle_id'] as String,
          name: [r['brand'], r['model']].whereType<String>().join(' '),
          alreadyMember: r['already_member'] as bool? ?? false,
        );
      });
}
