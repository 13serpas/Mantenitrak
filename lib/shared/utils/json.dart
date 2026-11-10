/// Conversión tolerante de valores JSON de Supabase (PostgREST puede
/// devolver NUMERIC como número o como texto según la configuración).
int? asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.round(),
      String s => int.tryParse(s) ?? double.tryParse(s)?.round(),
      _ => null,
    };

double? asDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

/// Las columnas DATE llegan como 'YYYY-MM-DD' y se interpretan en hora local.
DateTime? asDate(Object? v) => switch (v) {
      DateTime d => d,
      String s => DateTime.tryParse(s),
      _ => null,
    };

String? asText(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Filas embebidas (relación 1-N). Siempre devuelve una lista.
List<Map<String, dynamic>> asRows(Object? v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const [];
