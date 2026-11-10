import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/vehicle_draft.dart';
import '../domain/vehicle_specs.dart';
import 'vehicle_repository.dart';

final specsRepositoryProvider = Provider<SpecsRepository>(
  (ref) => SpecsRepository(ref.watch(supabaseClientProvider)),
);

/// Ficha técnica orientativa generada por IA.
///
/// Llama a la Edge Function `vehicle-specs`, que es la única que conoce la
/// clave de Anthropic. El prototipo llamaba a la API directamente desde la
/// app: sin clave no funcionaba, y con clave la habría expuesto a cualquiera.
class SpecsRepository {
  SpecsRepository(this._db);

  final SupabaseClient _db;

  Future<VehicleSpecs> generate(VehicleDraft draft) async {
    try {
      final res = await _db.functions.invoke(
        'vehicle-specs',
        body: {
          'type': draft.type!.name,
          'brand': draft.brand.trim(),
          'model': draft.model.trim(),
          'year': int.tryParse(draft.year.trim()),
          'engine': draft.engine.trim().isEmpty ? null : draft.engine.trim(),
          'fuel_type': draft.fuelType.isEmpty ? null : draft.fuelType,
        },
      );
      final data = res.data;
      final specs = data is Map ? data['specs'] : null;
      if (specs is! Map) {
        throw const DataFailure('La IA no ha devuelto una ficha válida.');
      }
      return VehicleSpecs.fromJson(Map<String, dynamic>.from(specs), source: SpecsSource.ia);
    } on FunctionException catch (e) {
      final details = e.details;
      final serverMsg = details is Map ? details['error'] as String? : null;
      throw DataFailure(switch (e.status) {
        404 => 'La función de IA no está desplegada en Supabase todavía.',
        503 => 'La IA no está configurada en el servidor (falta ANTHROPIC_API_KEY).',
        400 || 422 => serverMsg ?? 'No hay datos fiables para este vehículo.',
        _ => 'El servicio de IA no responde ahora mismo. Inténtalo más tarde.',
      }, '${e.status}: $details');
    } on DataFailure {
      rethrow;
    } on Exception catch (e) {
      throw DataFailure('No hay conexión con el servidor.', e.toString());
    }
  }
}
