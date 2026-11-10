import '../../../shared/utils/json.dart';
import '../../fuel/domain/fuel_log.dart';
import '../../maintenance/domain/maintenance_record.dart';

enum VehicleType {
  coche('Coche', '🚗'),
  moto('Moto', '🏍️'),
  camion('Camión', '🚛'),
  autobus('Autobús', '🚌'),
  furgoneta('Furgoneta', '🚐'),
  todoterreno('4x4', '🚙'),
  caravana('Caravana', '🚍'),
  barco('Barco', '⛵'),
  quad('Quad', '🏎️'),
  otro('Otro', '🚘');

  const VehicleType(this.label, this.emoji);
  final String label;
  final String emoji;

  static VehicleType parse(String? v) =>
      values.firstWhere((t) => t.name == v, orElse: () => otro);
}

/// Cómo accede el usuario actual a este vehículo.
enum AccessRole {
  owner('Propietario'),
  regular('Usuario habitual'),
  company('Empresa'),
  mechanic('Taller');

  const AccessRole(this.label);
  final String label;

  static AccessRole parse(String? v) =>
      values.firstWhere((r) => r.name == v, orElse: () => regular);
}

class KmLog {
  const KmLog({required this.km, required this.loggedAt});

  factory KmLog.fromJson(Map<String, dynamic> j) => KmLog(
        km: asInt(j['km']) ?? 0,
        loggedAt: asDate(j['logged_at']) ?? DateTime(2000),
      );

  final int km;
  final DateTime loggedAt;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.accessRole,
    this.engine,
    this.plate,
    this.fuelType,
    this.usage,
    this.zone = 'interior',
    this.ownerRole = 'owner',
    this.currentKm,
    this.annualKm,
    this.hasSpecs = false,
    this.sharedCount = 0,
    this.kmLogs = const [],
    this.maintenance = const [],
    this.fuelLogs = const [],
  });

  /// [j] es una fila de `vehicles` con sus tablas embebidas
  /// (ver VehicleRepository.selectWithRelations).
  factory Vehicle.fromJson(Map<String, dynamic> j, {required String currentUserId}) {
    final ownerId = j['owner_id'] as String;
    final shares = asRows(j['shared_vehicles']);
    final specs = j['vehicle_specs'];

    final AccessRole role;
    if (ownerId == currentUserId) {
      role = AccessRole.owner;
    } else {
      final mine = shares.where((s) => s['user_id'] == currentUserId);
      role = AccessRole.parse(mine.isEmpty ? null : mine.first['role'] as String?);
    }

    return Vehicle(
      id: j['id'] as String,
      ownerId: ownerId,
      type: VehicleType.parse(j['type'] as String?),
      brand: asText(j['brand']) ?? '',
      model: asText(j['model']) ?? '',
      year: asInt(j['year']) ?? 0,
      accessRole: role,
      engine: asText(j['engine']),
      plate: asText(j['plate']),
      fuelType: asText(j['fuel_type']),
      usage: asText(j['usage']),
      zone: asText(j['zone']) ?? 'interior',
      ownerRole: asText(j['role']) ?? 'owner',
      currentKm: asInt(j['current_km']),
      annualKm: asInt(j['annual_km']),
      // Relación 1-1: PostgREST devuelve un objeto (o null).
      hasSpecs: specs is Map || (specs is List && specs.isNotEmpty),
      sharedCount: shares.length,
      kmLogs: asRows(j['km_logs']).map(KmLog.fromJson).toList(),
      maintenance: asRows(j['maintenance_records']).map(MaintenanceRecord.fromJson).toList(),
      fuelLogs: asRows(j['fuel_logs']).map(FuelLog.fromJson).toList(),
    );
  }

  final String id;
  final String ownerId;
  final VehicleType type;
  final String brand;
  final String model;
  final int year;
  final AccessRole accessRole;
  final String? engine;
  final String? plate;
  final String? fuelType;
  final String? usage;
  final String zone;

  /// Relación que declaró el propietario al darlo de alta (columna `role`):
  /// owner, regular, company o mechanic.
  final String ownerRole;
  final int? currentKm;
  final int? annualKm;
  final bool hasSpecs;

  /// Personas con acceso compartido (solo fiable si eres el propietario:
  /// RLS no te deja ver los accesos de otros).
  final int sharedCount;
  final List<KmLog> kmLogs;
  final List<MaintenanceRecord> maintenance;
  final List<FuelLog> fuelLogs;

  bool get isOwner => accessRole == AccessRole.owner;

  /// Aparece en el modo taller: me lo han compartido como taller, o lo di de
  /// alta yo declarándome taller.
  bool get isWorkshop =>
      accessRole == AccessRole.mechanic || (isOwner && ownerRole == 'mechanic');

  String get displayName => '$brand $model'.trim();

  /// "2019 · 1.5 TSI · 4521 HJK"
  String get subtitle => [
        if (year > 0) '$year',
        if (engine != null) engine!,
        if (plate != null) plate!,
      ].join(' · ');
}
