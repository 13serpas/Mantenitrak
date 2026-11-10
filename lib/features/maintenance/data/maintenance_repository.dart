import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../vehicles/domain/vehicle.dart';
import '../domain/maintenance_entry.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(ref.watch(supabaseClientProvider)),
);

/// Registro de mantenimientos y sus fotos (bucket privado de Storage).
class MaintenanceRepository {
  MaintenanceRepository(this._db);

  final SupabaseClient _db;

  static const bucket = 'maintenance-photos';

  StorageFileApi get _storage => _db.storage.from(bucket);

  /// Nombre de archivo difícil de adivinar: `<vehicle_id>/<aleatorio>.jpg`.
  /// La carpeta del vehículo es la que comprueban las políticas de Storage.
  static String newPhotoPath(String vehicleId, String extension, [Random? random]) {
    final r = random ?? Random.secure();
    final name = List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
    return '$vehicleId/$name.$extension';
  }

  /// Sube las fotos y registra todos los trabajos en una transacción.
  /// Si el registro falla, borra las fotos ya subidas.
  /// [onProgress] recibe (fotos subidas, total).
  Future<int> register(
    String vehicleId,
    MaintenanceEntry entry, {
    required VehicleType type,
    void Function(int done, int total)? onProgress,
  }) =>
      guardData(() async {
        final uploaded = <String, List<String>>{};
        final all = <String>[];
        final total = entry.photoCount;
        try {
          for (final line in entry.lines) {
            for (final photo in line.photos) {
              final path = newPhotoPath(vehicleId, photo.extension);
              await _storage.uploadBinary(
                path,
                photo.bytes,
                fileOptions: FileOptions(contentType: photo.mimeType, upsert: false),
              );
              all.add(path);
              uploaded.putIfAbsent(line.key, () => []).add(path);
              onProgress?.call(all.length, total);
            }
          }
          final count = await _db.rpc('register_maintenance', params: entry.toRpcParams(vehicleId, uploaded, type: type));
          return (count as num).toInt();
        } catch (_) {
          await removePhotos(all);
          rethrow;
        }
      });

  /// URLs temporales (1 hora) para ver fotos privadas. Las fotos antiguas
  /// del prototipo (base64 o http) se devuelven tal cual.
  Future<Map<String, String>> photoUrls(List<String> paths) => guardData(() async {
        final out = <String, String>{};
        final storagePaths = <String>[];
        for (final p in paths) {
          if (p.startsWith('data:') || p.startsWith('http')) {
            out[p] = p;
          } else {
            storagePaths.add(p);
          }
        }
        if (storagePaths.isNotEmpty) {
          final signed = await _storage.createSignedUrls(storagePaths, 3600);
          for (final s in signed) {
            out[s.path] = s.signedUrl;
          }
        }
        return out;
      });

  /// Borra fotos de Storage. No falla si alguna ya no existe o no se tiene
  /// permiso: es limpieza.
  Future<void> removePhotos(List<String> paths) async {
    final storagePaths = [for (final p in paths) if (!p.startsWith('data:') && !p.startsWith('http')) p];
    if (storagePaths.isEmpty) return;
    try {
      await _storage.remove(storagePaths);
    } catch (_) {
      // Limpieza en segundo plano: un fallo aquí no debe bloquear al usuario.
    }
  }

  /// Borra todas las fotos de un vehículo (antes de eliminarlo).
  Future<void> removeVehicleFolder(String vehicleId) async {
    try {
      final files = await _storage.list(path: vehicleId, searchOptions: const SearchOptions(limit: 1000));
      await removePhotos([for (final f in files) '$vehicleId/${f.name}']);
    } catch (_) {
      // Igual que arriba: no impide eliminar el vehículo.
    }
  }
}
