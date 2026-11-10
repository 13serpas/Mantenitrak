import 'package:supabase_flutter/supabase_flutter.dart';

/// Error de datos ya traducido para la UI.
class DataFailure implements Exception {
  const DataFailure(this.message, [this.detail]);
  final String message;
  final String? detail;

  @override
  String toString() => 'DataFailure($message, $detail)';
}

/// Ejecuta una llamada a Supabase y convierte cualquier error en un
/// [DataFailure] con un mensaje listo para mostrar.
Future<T> guardData<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DataFailure {
    rethrow;
  } on PostgrestException catch (e) {
    throw DataFailure(_postgrestMessage(e), '${e.code}: ${e.message}');
  } on StorageException catch (e) {
    throw DataFailure(_storageMessage(e), '${e.statusCode}: ${e.message}');
  } on AuthException catch (e) {
    throw DataFailure('Tu sesión ha caducado. Vuelve a iniciar sesión.', e.message);
  } on Exception catch (e) {
    throw DataFailure('No hay conexión con el servidor. Comprueba tu conexión.', e.toString());
  }
}

String _postgrestMessage(PostgrestException e) => switch (e.code) {
      // Nuestras funciones SQL explican el motivo en español; los errores
      // genéricos de Postgres (RLS, permisos) no se enseñan tal cual.
      '42501' => _isOwnMessage(e.message) ? e.message : 'No tienes permiso para hacer esto en este vehículo.',
      '22023' => e.message, // mensajes de validación de nuestras funciones SQL
      '22P02' || '23514' => 'Algún dato no es válido. Revisa el formulario.',
      'PGRST202' => 'Faltan migraciones por aplicar en Supabase (003 a 008).',
      _ => 'No se han podido cargar los datos. Inténtalo de nuevo.',
    };

String _storageMessage(StorageException e) {
  final code = e.statusCode ?? '';
  if (code == '413' || e.message.contains('size')) return 'La foto es demasiado grande (máximo 5 MB).';
  if (code == '404' || e.message.contains('Bucket not found')) {
    return 'Falta crear el almacenamiento de fotos en Supabase (migración 006).';
  }
  if (code == '403' || e.message.contains('row-level') || e.message.contains('Unauthorized')) {
    return 'No tienes permiso para guardar fotos en este vehículo.';
  }
  if (e.message.contains('mime')) return 'Formato de foto no admitido. Usa JPG, PNG o WebP.';
  return 'No se ha podido subir la foto. Inténtalo de nuevo.';
}

bool _isOwnMessage(String m) =>
    !m.contains('policy') && !m.contains('permission denied') && !m.contains('row-level');
