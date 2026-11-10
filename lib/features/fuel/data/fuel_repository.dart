import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/fuel_entry.dart';

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => FuelRepository(ref.watch(supabaseClientProvider)),
);

/// Repostajes (punto 6). Se guardan con la función `register_fuel`
/// (migración 007), que calcula el importe que falta, comprueba los km
/// y los apunta en el historial de lecturas también en vehículos
/// compartidos.
class FuelRepository {
  FuelRepository(this._db);

  final SupabaseClient _db;

  /// Devuelve el id del repostaje.
  Future<String> register(String vehicleId, FuelEntry entry) => guardData(() async {
        final id = await _db.rpc('register_fuel', params: entry.toRpcParams(vehicleId));
        return id as String;
      });
}
