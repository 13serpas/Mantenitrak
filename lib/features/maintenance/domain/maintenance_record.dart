import '../../../shared/utils/json.dart';
import 'maintenance_catalog.dart';

class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.itemId,
    required this.performedAt,
    this.userId,
    this.itemName,
    this.km,
    this.cost,
    this.costEstimated = false,
    this.notes,
    this.photos = const [],
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> j) => MaintenanceRecord(
        id: j['id'] as String,
        // Unifica los IDs antiguos del prototipo (frenos_del, liq_frenos…).
        itemId: MaintenanceCatalog.normalizeId(j['item_id'] as String),
        performedAt: asDate(j['performed_at']) ?? DateTime(2000),
        userId: asText(j['user_id']),
        itemName: asText(j['item_name']),
        km: asInt(j['km']),
        cost: asDouble(j['cost']),
        costEstimated: j['cost_estimated'] == true,
        notes: asText(j['notes']),
        photos: j['photos'] is List ? [for (final p in j['photos'] as List) if (p is String && p.isNotEmpty) p] : const [],
      );

  final String id;
  final String itemId;
  final DateTime performedAt;

  /// Quién lo registró. Solo esa persona puede borrarlo (política RLS).
  final String? userId;

  /// Nombre guardado al registrarlo (para elementos que ya no están en el plan).
  final String? itemName;
  final int? km;
  final double? cost;

  /// El coste sale de repartir un total entre varios trabajos (punto 5).
  final bool costEstimated;
  final String? notes;
  /// Rutas en Storage (`<vehicle_id>/<nombre>.jpg`). Los registros del
  /// prototipo pueden traer fotos en base64 (`data:image/...`).
  final List<String> photos;

  int get photoCount => photos.length;

  /// Fotos que están en el bucket (las base64 antiguas no se borran de Storage).
  List<String> get storagePhotos => [for (final p in photos) if (!p.startsWith('data:') && !p.startsWith('http')) p];
}
