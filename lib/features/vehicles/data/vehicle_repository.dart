import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../shared/utils/formatters.dart';
import '../domain/vehicle.dart';
import '../domain/vehicle_detail.dart';
import '../domain/vehicle_draft.dart';
import '../domain/vehicle_specs.dart';

// Muchas pantallas importan DataFailure desde aquí.
export '../../../core/supabase/data_failure.dart' show DataFailure;

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(ref.watch(supabaseClientProvider)),
);

class VehicleRepository {
  VehicleRepository(this._db);

  final SupabaseClient _db;

  /// Un vehículo con todo lo que necesita la pantalla de inicio, en UNA
  /// consulta (el prototipo lanzaba 7 consultas por vehículo).
  static const selectWithRelations = '''
    *,
    vehicle_specs(id),
    shared_vehicles(user_id, role),
    km_logs(km, logged_at),
    maintenance_records(id, item_id, performed_at, km, cost),
    fuel_logs(id, logged_at, km, liters, total, full_tank, fuel_type)
  ''';

  /// Vehículos propios y compartidos conmigo. No hace falta filtrar:
  /// la política RLS de `vehicles` ya devuelve exactamente esos.
  Future<List<Vehicle>> fetchMine(String userId) => _guard(() async {
        final rows = await _db
            .from('vehicles')
            .select(selectWithRelations)
            .order('created_at', ascending: false)
            .order('logged_at', ascending: false, referencedTable: 'km_logs')
            .limit(12, referencedTable: 'km_logs')
            .order('logged_at', ascending: false, referencedTable: 'fuel_logs')
            .limit(40, referencedTable: 'fuel_logs');
        return rows.map((r) => Vehicle.fromJson(r, currentUserId: userId)).toList();
      });

  /// Todo lo que muestra el detalle, en UNA consulta. El prototipo lanzaba
  /// siete (vehículo, ficha, km, mantenimientos, repostajes, accesos y
  /// gastos). null si no existe o no tienes acceso (RLS lo oculta).
  static const selectDetail = '''
    *,
    vehicle_specs(*),
    shared_vehicles(user_id, role),
    km_logs(km, logged_at),
    maintenance_records(id, user_id, item_id, item_name, performed_at, km, cost, cost_estimated, notes, photos),
    fuel_logs(id, user_id, logged_at, km, liters, price_per_liter, total, fuel_type, full_tank, station),
    expenses(id, user_id, category, amount, paid_at, description)
  ''';

  Future<VehicleDetail?> fetchDetail(String vehicleId, String userId) => _guard(() async {
        final row = await _db
            .from('vehicles')
            .select(selectDetail)
            .eq('id', vehicleId)
            .order('logged_at', ascending: false, referencedTable: 'km_logs')
            .limit(60, referencedTable: 'km_logs')
            .order('performed_at', ascending: false, referencedTable: 'maintenance_records')
            .order('logged_at', ascending: false, referencedTable: 'fuel_logs')
            .order('paid_at', ascending: false, referencedTable: 'expenses')
            .maybeSingle();
        return row == null ? null : VehicleDetail.fromJson(row, currentUserId: userId);
      });

  /// Edita los datos del vehículo (solo el propietario; función
  /// `update_vehicle`, migración 005).
  Future<void> updateVehicle(String vehicleId, VehicleDraft draft) => _guard(() => _db.rpc(
        'update_vehicle',
        params: {'p_vehicle_id': vehicleId, 'p_vehicle': draft.toUpdateJson()},
      ));

  /// Guarda la ficha técnica; una ficha vacía (o null) la elimina.
  Future<void> saveSpecs(String vehicleId, VehicleSpecs? specs) => _guard(() => _db.rpc(
        'save_vehicle_specs',
        params: {
          'p_vehicle_id': vehicleId,
          'p_specs': (specs == null || specs.isEmpty) ? null : specs.toJson(),
        },
      ));

  /// Borra el vehículo y todo su historial (cascada). Solo el propietario.
  Future<void> deleteVehicle(String vehicleId) => _guard(() async {
        // Con RLS, borrar algo ajeno no da error: simplemente no borra nada.
        final deleted = await _db.from('vehicles').delete().eq('id', vehicleId).select('id');
        if (deleted.isEmpty) {
          throw const DataFailure('Solo el propietario puede eliminar este vehículo.');
        }
      });

  /// Deja de ver un vehículo que te habían compartido.
  Future<void> leaveVehicle(String vehicleId, String userId) => _guard(() async {
        await _db.from('shared_vehicles').delete().eq('vehicle_id', vehicleId).eq('user_id', userId);
      });

  /// Borra un mantenimiento. Solo quien lo registró (política RLS).
  Future<void> deleteMaintenanceRecord(String recordId) => _guard(() async {
        final deleted =
            await _db.from('maintenance_records').delete().eq('id', recordId).select('id');
        if (deleted.isEmpty) {
          throw const DataFailure('Solo quien registró este mantenimiento puede borrarlo.');
        }
      });

  /// Solo quien lo registró puede borrarlo (RLS). Si no borra nada, avisa.
  Future<void> deleteFuelLog(String logId) => _guard(() async {
        final deleted = await _db.from('fuel_logs').delete().eq('id', logId).select('id');
        if (deleted.isEmpty) {
          throw const DataFailure('Solo quien registró este repostaje puede borrarlo.');
        }
      });

  /// Registra una lectura del odómetro. Usa la función `log_km` (migración
  /// 003) para que también funcione con vehículos compartidos.
  Future<void> logKm(String vehicleId, int km) => _guard(() => _db.rpc(
        'log_km',
        params: {
          'p_vehicle_id': vehicleId,
          'p_km': km,
          'p_date': Fmt.isoDate(DateTime.now()),
        },
      ));

  /// Crea vehículo + primera lectura de km + ficha en una sola transacción
  /// (función `create_vehicle`, migración 004). Devuelve el id.
  Future<String> createVehicle(VehicleDraft draft, {VehicleSpecs? specs}) => _guard(() async {
        final id = await _db.rpc(
          'create_vehicle',
          params: {
            'p_vehicle': draft.toJson(),
            'p_specs': (specs == null || specs.isEmpty) ? null : specs.toJson(),
          },
        );
        return id as String;
      });

  Future<T> _guard<T>(Future<T> Function() run) => guardData(run);
}
