import 'dart:typed_data';

import '../../../shared/utils/formatters.dart';
import '../../vehicles/domain/vehicle.dart';
import 'maintenance_catalog.dart';
import 'reference_prices.dart';

/// Foto elegida en el móvil, aún sin subir.
class EntryPhoto {
  const EntryPhoto({required this.localId, required this.bytes, required this.extension});

  final String localId;
  final Uint8List bytes;

  /// jpg, png o webp (lo que admite el bucket).
  final String extension;

  String get mimeType => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  /// Extensión admitida a partir del nombre del archivo; null si no vale.
  static String? extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => null,
    };
  }
}

/// Un trabajo marcado en el formulario.
class EntryLine {
  const EntryLine({
    required this.key,
    required this.itemId,
    required this.name,
    required this.icon,
    this.cost = '',
    this.photos = const [],
  });

  factory EntryLine.fromItem(MaintenanceItem item) =>
      EntryLine(key: item.id, itemId: item.id, name: item.name, icon: item.icon);

  /// Trabajo que no está en el plan (reparación, revisión…).
  factory EntryLine.custom(int n) => EntryLine(key: 'otro-$n', itemId: customId, name: '', icon: '🔧');

  static const customId = 'otro';

  /// Identificador único en el formulario (para "otro" puede haber varios).
  final String key;
  final String itemId;
  final String name;
  final String icon;
  final String cost;
  final List<EntryPhoto> photos;

  bool get isCustom => itemId == customId;

  EntryLine copyWith({String? name, String? cost, List<EntryPhoto>? photos}) => EntryLine(
        key: key,
        itemId: itemId,
        name: name ?? this.name,
        icon: icon,
        cost: cost ?? this.cost,
        photos: photos ?? this.photos,
      );
}

/// Cómo se indica el coste.
enum CostMode {
  /// Un importe por trabajo.
  perItem,

  /// Solo se sabe el total: se reparte con [ReferencePrices].
  total,
}

/// Formulario de "Registrar mantenimiento": fecha y km comunes, uno o
/// varios trabajos con su coste y sus fotos, y notas.
class MaintenanceEntry {
  const MaintenanceEntry({
    required this.date,
    this.km = '',
    this.notes = '',
    this.lines = const [],
    this.costMode = CostMode.perItem,
    this.totalCost = '',
  });

  /// Empieza con la fecha de hoy, los km actuales y los trabajos que
  /// vengan preseleccionados (p. ej. desde "¿Qué hacer?").
  factory MaintenanceEntry.initial({
    required List<MaintenanceItem> plan,
    Iterable<String> preselected = const [],
    int? currentKm,
    DateTime? today,
  }) {
    final wanted = preselected.map(MaintenanceCatalog.normalizeId).toSet();
    final now = today ?? DateTime.now();
    return MaintenanceEntry(
      date: DateTime(now.year, now.month, now.day),
      km: currentKm?.toString() ?? '',
      lines: [for (final i in plan) if (wanted.contains(i.id)) EntryLine.fromItem(i)],
    );
  }

  static const maxLines = 40;
  static const maxPhotosPerLine = 6;
  static const maxCost = 99999.0;

  final DateTime date;
  final String km;
  final String notes;
  final List<EntryLine> lines;
  final CostMode costMode;

  /// Importe total cuando [costMode] es [CostMode.total].
  final String totalCost;

  bool isSelected(String key) => lines.any((l) => l.key == key);

  MaintenanceEntry copyWith({
    DateTime? date,
    String? km,
    String? notes,
    List<EntryLine>? lines,
    CostMode? costMode,
    String? totalCost,
  }) =>
      MaintenanceEntry(
        date: date ?? this.date,
        km: km ?? this.km,
        notes: notes ?? this.notes,
        lines: lines ?? this.lines,
        costMode: costMode ?? this.costMode,
        totalCost: totalCost ?? this.totalCost,
      );

  /// Marca o desmarca un elemento del plan.
  MaintenanceEntry toggle(MaintenanceItem item) => isSelected(item.id)
      ? copyWith(lines: [for (final l in lines) if (l.key != item.id) l])
      : copyWith(lines: [...lines, EntryLine.fromItem(item)]);

  /// Deja marcados exactamente estos elementos, conservando coste y fotos
  /// de los que ya estaban (y los trabajos "otro").
  MaintenanceEntry selectOnly(Iterable<MaintenanceItem> items) {
    final keep = {for (final l in lines) l.key: l};
    return copyWith(lines: [
      for (final i in items) keep[i.id] ?? EntryLine.fromItem(i),
      for (final l in lines) if (l.isCustom) l,
    ]);
  }

  MaintenanceEntry addCustom() {
    var n = 1;
    while (isSelected('otro-$n')) {
      n++;
    }
    return copyWith(lines: [...lines, EntryLine.custom(n)]);
  }

  MaintenanceEntry removeLine(String key) => copyWith(lines: [for (final l in lines) if (l.key != key) l]);

  MaintenanceEntry updateLine(String key, EntryLine Function(EntryLine) update) =>
      copyWith(lines: [for (final l in lines) l.key == key ? update(l) : l]);

  int get photoCount => lines.fold(0, (s, l) => s + l.photos.length);

  /// Coste total: el escrito en modo total o la suma de los de cada
  /// trabajo (los no válidos no cuentan).
  double get total => costMode == CostMode.total
      ? (parseCost(totalCost) ?? 0)
      : lines.fold<double>(0, (s, l) => s + (parseCost(l.cost) ?? 0));

  /// En modo total con varios trabajos, el coste de cada uno es una
  /// estimación (reparto según precios de referencia).
  bool get costsAreEstimated => costMode == CostMode.total && lines.length > 1 && parseCost(totalCost) != null;

  /// Coste de cada línea (por `key`) tal como se guardará. En modo total
  /// se reparte el importe según [ReferencePrices].
  Map<String, double?> costsFor(VehicleType type) {
    if (costMode == CostMode.perItem) return {for (final l in lines) l.key: parseCost(l.cost)};
    final t = parseCost(totalCost);
    if (t == null) return {for (final l in lines) l.key: null};
    return ReferencePrices.split(t, [for (final l in lines) (key: l.key, itemId: l.itemId)], type);
  }

  // ── Validación (misma regla que la función SQL) ──────────────

  /// "89,90", "89.90", "1.234,50" o "1234" → número. null si vacío o no vale.
  static double? parseCost(String text) {
    var t = text.replaceAll('€', '').replaceAll(' ', '').trim();
    if (t.isEmpty) return null;
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.'); // formato español
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', ''); // 1.234 = mil doscientos
    }
    return double.tryParse(t);
  }

  static String? validateCost(String text) {
    if (text.trim().isEmpty) return null;
    final v = parseCost(text);
    if (v == null) return 'Escribe un número';
    if (v < 0 || v > maxCost) return 'Entre 0 y 99.999 €';
    return null;
  }

  static String? validateCustomName(String name) =>
      name.trim().isEmpty ? 'Escribe qué trabajo se hizo' : null;

  /// Los km son opcionales, pero si se escriben deben encajar con las
  /// lecturas: no menos que una del mismo día o anterior, ni más que una
  /// de un día posterior.
  static String? validateKm(String text, DateTime date, List<KmLog> logs) {
    final t = text.replaceAll('.', '').replaceAll(' ', '').trim();
    if (t.isEmpty) return null;
    final km = int.tryParse(t);
    if (km == null || km < 0) return 'Escribe solo números';
    if (km > 3000000) return 'Parece demasiado. Revísalo';
    final day = DateTime(date.year, date.month, date.day);
    KmLog? before;
    KmLog? after;
    for (final l in logs) {
      final d = DateTime(l.loggedAt.year, l.loggedAt.month, l.loggedAt.day);
      if (!d.isAfter(day) && l.km > km && (before == null || l.km > before.km)) before = l;
      if (d.isAfter(day) && l.km < km && (after == null || l.km < after.km)) after = l;
    }
    if (before != null) {
      return 'Menos que una lectura anterior (${Fmt.km(before.km)} el ${Fmt.date(before.loggedAt)})';
    }
    if (after != null) {
      return 'Más que una lectura posterior (${Fmt.km(after.km)} el ${Fmt.date(after.loggedAt)})';
    }
    return null;
  }

  static int? parseKm(String text) {
    final t = text.replaceAll('.', '').replaceAll(' ', '').trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  /// Primer problema que impide guardar, o null si todo está bien.
  String? validate(List<KmLog> logs, {DateTime? today}) {
    final now = today ?? DateTime.now();
    if (lines.isEmpty) return 'Marca al menos un trabajo.';
    if (lines.length > maxLines) return 'Demasiados trabajos en un solo registro.';
    if (date.isAfter(DateTime(now.year, now.month, now.day))) return 'La fecha no puede ser futura.';
    final kmError = validateKm(km, date, logs);
    if (kmError != null) return kmError;
    if (costMode == CostMode.total && validateCost(totalCost) != null) return 'Revisa el coste total.';
    for (final l in lines) {
      if (l.isCustom && validateCustomName(l.name) != null) return 'Escribe el nombre de cada "otro trabajo".';
      if (costMode == CostMode.perItem && validateCost(l.cost) != null) {
        return 'Revisa el coste de ${l.name.isEmpty ? 'otro trabajo' : l.name}.';
      }
      if (l.photos.length > maxPhotosPerLine) return 'Máximo $maxPhotosPerLine fotos por trabajo.';
    }
    return null;
  }

  /// Parámetros de `register_maintenance`. [uploaded] = rutas en Storage
  /// de las fotos de cada línea (por `key`).
  Map<String, dynamic> toRpcParams(
    String vehicleId,
    Map<String, List<String>> uploaded, {
    VehicleType type = VehicleType.coche,
  }) {
    final costs = costsFor(type);
    final estimated = costsAreEstimated;
    return {
        'p_vehicle_id': vehicleId,
        'p_date': Fmt.isoDate(date),
        'p_km': parseKm(km),
        'p_notes': notes.trim().isEmpty ? null : notes.trim(),
        'p_items': [
          for (final l in lines)
            {
              'item_id': l.itemId,
              'item_name': l.name.trim(),
              'cost': costs[l.key],
              'cost_estimated': estimated,
              'photos': uploaded[l.key] ?? const <String>[],
            },
        ],
      };
  }
}
