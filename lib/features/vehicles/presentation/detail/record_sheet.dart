import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../maintenance/domain/maintenance_record.dart';
import '../providers/vehicle_detail_provider.dart';

/// Detalle de un mantenimiento del historial, con sus fotos.
Future<void> showRecordSheet(
  BuildContext context, {
  required MaintenanceRecord record,
  required String name,
  required String icon,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecordSheet(record: record, name: name, icon: icon),
    );

class _RecordSheet extends StatelessWidget {
  const _RecordSheet({required this.record, required this.name, required this.icon});

  final MaintenanceRecord record;
  final String name;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = record;
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 90, child: Text(label, style: TextStyle(color: c.textMid))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: Text(icon, style: const TextStyle(fontSize: 26))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              line('Fecha', Fmt.date(r.performedAt)),
              if (r.km != null) line('Km', Fmt.km(r.km!)),
              if (r.cost != null)
                line(
                  r.costEstimated ? 'Coste ≈' : 'Coste',
                  r.costEstimated ? '${Fmt.money(r.cost!)} (reparto estimado del total)' : Fmt.money(r.cost!),
                ),
              if (r.notes != null) line('Notas', r.notes!),
              if (r.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Fotos', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                RecordPhotos(paths: r.photos),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniaturas de fotos guardadas (Storage privado, base64 antigua o URL).
class RecordPhotos extends ConsumerWidget {
  const RecordPhotos({super.key, required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(photoUrlsProvider(paths.join('\n')));
    return urls.when(
      loading: () => const SizedBox(height: 90, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => Text('No se han podido cargar las fotos.', style: TextStyle(color: context.colors.textMid)),
      data: (map) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, p) in paths.indexed)
            if (map[p] != null)
              Semantics(
                button: true,
                label: 'Foto ${i + 1} de ${paths.length}. Pulsa para ampliarla.',
                child: GestureDetector(
                  onTap: () => _openFull(context, map[p]!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 96, height: 96, child: photoImage(map[p]!, fit: BoxFit.cover)),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static void _openFull(BuildContext context, String url) => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InteractiveViewer(child: photoImage(url, fit: BoxFit.contain)),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Imagen desde una URL firmada, http o `data:image/...;base64,...`.
Widget photoImage(String src, {BoxFit fit = BoxFit.cover}) {
  Widget broken(BuildContext context) =>
      ColoredBox(color: context.colors.surfaceAlt, child: const Center(child: Icon(Icons.broken_image_outlined)));
  if (src.startsWith('data:')) {
    final comma = src.indexOf(',');
    try {
      return Image.memory(base64Decode(src.substring(comma + 1)), fit: fit);
    } catch (_) {
      return Builder(builder: broken);
    }
  }
  return Image.network(src, fit: fit, errorBuilder: (context, _, __) => broken(context));
}
