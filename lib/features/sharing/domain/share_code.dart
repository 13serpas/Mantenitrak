import '../../../shared/utils/formatters.dart';
import '../../vehicles/domain/vehicle.dart';

/// Códigos para compartir un vehículo (punto 7). Mismas reglas que SQL
/// (`generate_share_code` y `join_vehicle_by_code`, migraciones 003 y 008).
abstract final class ShareCode {
  static const length = 6;

  /// Alfabeto sin caracteres que se confunden (0/O, 1/I/L).
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Prefijo del enlace del QR. El esquema es el mismo que el del
  /// enlace de confirmación de cuenta; "app" es el host (se ignora) y la
  /// ruta llega al router como /join/CODIGO.
  static const linkPrefix = 'mantenitrak://app/join/';

  /// Mayúsculas y sin espacios ni guiones: "abc 23-4" → "ABC234".
  static String normalize(String text) => text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// null si es válido; si no, el mensaje para el usuario.
  static String? validate(String text) {
    final c = normalize(text);
    if (c.isEmpty) return 'Escribe el código';
    if (c.length != length) return 'El código tiene $length letras y números';
    if (c.split('').any((ch) => !alphabet.contains(ch))) return 'Los códigos no llevan 0, 1, I, L ni O';
    return null;
  }

  /// Código que hay dentro de un QR leído: el enlace de la app, un enlace
  /// con `?code=`, o el código a secas. null si no parece de ManteniTrack.
  static String? fromScan(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    String? candidate;
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'mantenitrak') return null;
      final segs = uri.pathSegments;
      final i = segs.indexOf('join');
      candidate = uri.queryParameters['code'] ?? (i >= 0 && i + 1 < segs.length ? segs[i + 1] : null);
    } else {
      candidate = text;
    }
    if (candidate == null) return null;
    final c = normalize(candidate);
    return validate(c) == null ? c : null;
  }

  static String link(String code) => '$linkPrefix$code';

  /// "ABC123" → "ABC 123" (más fácil de dictar).
  static String pretty(String code) =>
      code.length == length ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

  /// Texto para WhatsApp, correo…
  static String message({required String vehicleName, required String code, required DateTime expiresAt}) =>
      'Te invito a ver el $vehicleName en ManteniTrack.\n\n'
      'Abre la app, pulsa «Unirme a un vehículo» y escribe el código ${pretty(code)} '
      '(vale hasta el ${Fmt.date(expiresAt)}).\n\n'
      'O abre este enlace desde el móvil: ${link(code)}';
}

/// Una persona con acceso al vehículo (función `vehicle_members`).
class VehicleMember {
  const VehicleMember({
    required this.userId,
    required this.role,
    this.displayName,
    this.joinedAt,
    this.isMe = false,
  });

  factory VehicleMember.fromJson(Map<String, dynamic> j) => VehicleMember(
        userId: j['user_id'] as String,
        displayName: (j['display_name'] as String?)?.trim().isEmpty ?? true ? null : (j['display_name'] as String).trim(),
        role: AccessRole.parse(j['role'] as String?),
        joinedAt: DateTime.tryParse(j['joined_at']?.toString() ?? '')?.toLocal(),
        isMe: j['is_me'] as bool? ?? false,
      );

  final String userId;
  final String? displayName;
  final AccessRole role;
  final DateTime? joinedAt;
  final bool isMe;

  String get name => displayName ?? 'Usuario sin nombre';

  /// Iniciales para el avatar: "Ana López" → "AL".
  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }
}

/// Código vigente de un vehículo.
class ShareInvite {
  const ShareInvite({required this.code, required this.expiresAt});

  factory ShareInvite.fromJson(Map<String, dynamic> j) => ShareInvite(
        code: j['code'] as String,
        expiresAt: DateTime.parse(j['expires_at'].toString()).toLocal(),
      );

  final String code;
  final DateTime expiresAt;

  /// "Caduca hoy", "Caduca mañana", "Caduca en 6 días".
  String expiryLabel([DateTime? now]) {
    final n = now ?? DateTime.now();
    final days = DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
        .difference(DateTime(n.year, n.month, n.day))
        .inDays;
    if (days <= 0) return 'Caduca hoy';
    if (days == 1) return 'Caduca mañana';
    return 'Caduca en $days días (${Fmt.date(expiresAt)})';
  }
}

/// Resultado de unirse con un código.
class JoinResult {
  const JoinResult({required this.vehicleId, required this.name, required this.alreadyMember});

  final String vehicleId;
  final String name;
  final bool alreadyMember;
}
