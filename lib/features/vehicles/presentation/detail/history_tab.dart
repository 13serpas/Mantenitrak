import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../maintenance/domain/maintenance_catalog.dart';
import '../../../maintenance/domain/maintenance_record.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../providers/vehicle_detail_provider.dart';
import 'detail_widgets.dart';
import 'record_sheet.dart';

/// Pestaña "Historial": todos los mantenimientos, con búsqueda y filtro.
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key, required this.vehicle, required this.onRegisterMaintenance});

  final Vehicle vehicle;
  final VoidCallback onRegisterMaintenance;

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  /// Registros quitados con el gesto mientras el servidor confirma. Un
  /// Dismissible deslizado debe salir del árbol en el mismo fotograma.
  final _removed = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Todos los elementos posibles del tipo (también los que el plan
  /// excluye por combustible), para nombrar registros antiguos.
  Map<String, MaintenanceItem> get _items => {
        for (final i in MaintenanceCatalog.basePlan(widget.vehicle.type)) i.id: i,
      };

  String _nameOf(MaintenanceRecord r) =>
      _items[r.itemId]?.name ?? r.itemName ?? r.itemId.replaceAll('_', ' ');

  Future<bool> _confirmDelete(MaintenanceRecord r) => confirmDialog(
        context,
        title: 'Eliminar registro',
        message: '¿Seguro que quieres eliminar el registro de ${_nameOf(r)} del ${Fmt.date(r.performedAt)}?',
        confirmLabel: 'Eliminar',
        destructive: true,
      );

  Future<void> _delete(MaintenanceRecord r) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removed.add(r.id));
    try {
      await ref.read(vehicleActionsProvider).deleteRecord(widget.vehicle.id, r);
      messenger.showSnackBar(const SnackBar(content: Text('Registro eliminado')));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      // No se ha borrado: vuelve a mostrarse.
      if (mounted) setState(() => _removed.remove(r.id));
    }
  }

  void _open(MaintenanceRecord r) =>
      showRecordSheet(context, record: r, name: _nameOf(r), icon: _items[r.itemId]?.icon ?? '🔧');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final userId = ref.watch(currentUserIdProvider);
    final records = widget.vehicle.maintenance.where((r) => !_removed.contains(r.id)).toList();

    if (records.isEmpty) {
      return DetailTabScroll(
        storageKey: 'historial',
        children: [
          EmptyTabMessage(
            emoji: '📋',
            title: 'Sin registros',
            body: 'Cada mantenimiento que registres aparecerá aquí, con su fecha, sus km y lo que costó.',
            actionLabel: 'Registrar mantenimiento',
            onAction: widget.onRegisterMaintenance,
          ),
        ],
      );
    }

    final categories = {for (final r in records) _items[r.itemId]?.category ?? 'Otros'}.toList()..sort();
    final q = _query.trim().toLowerCase();
    final filtered = records.where((r) {
      final cat = _items[r.itemId]?.category ?? 'Otros';
      if (_category != null && cat != _category) return false;
      if (q.isEmpty) return true;
      return [_nameOf(r), r.notes ?? '', Fmt.date(r.performedAt)].any((s) => s.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final total = filtered.fold<double>(0, (s, r) => s + (r.cost ?? 0));

    return DetailTabScroll(
      storageKey: 'historial',
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar en el historial…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        if (categories.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _category == null,
                onSelected: (_) => setState(() => _category = null),
              ),
              for (final cat in categories)
                ChoiceChip(
                  label: Text(cat),
                  selected: _category == cat,
                  onSelected: (_) => setState(() => _category = _category == cat ? null : cat),
                ),
            ],
          ),
        Text(
          '${plural(filtered.length, 'registro', 'registros')}'
          '${total > 0 ? ' · ${Fmt.euros(total)}' : ''}',
          style: TextStyle(color: c.textSoft, fontSize: 12.5),
        ),
        if (filtered.isEmpty)
          const EmptyTabMessage(
            emoji: '🔎',
            title: 'Sin resultados',
            body: 'Prueba con otra búsqueda o quita el filtro.',
          ),
        for (final r in filtered)
          r.userId != null && r.userId == userId
              ? Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(r),
                  onDismissed: (_) => _delete(r),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: _RecordRow(
                    record: r,
                    name: _nameOf(r),
                    icon: _items[r.itemId]?.icon ?? '🔧',
                    onOpen: () => _open(r),
                    onDelete: () async {
                      if (await _confirmDelete(r)) await _delete(r);
                    },
                  ),
                )
              : _RecordRow(record: r, name: _nameOf(r), icon: _items[r.itemId]?.icon ?? '🔧', onOpen: () => _open(r)),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.name,
    required this.icon,
    required this.onOpen,
    this.onDelete,
  });

  final MaintenanceRecord record;
  final String name;
  final String icon;

  /// Abre el detalle con notas y fotos.
  final VoidCallback onOpen;

  /// Alternativa accesible al gesto de deslizar (solo registros propios).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = record;
    final details = [
      Fmt.date(r.performedAt),
      if (r.km != null) Fmt.km(r.km!),
      if (r.notes != null) r.notes!,
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: onOpen,
      child: Row(
        children: [
          ExcludeSemantics(child: Text(icon, style: const TextStyle(fontSize: 18))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (r.photoCount > 0) ...[
                      const SizedBox(width: 6),
                      Text('📷 ${r.photoCount}', style: TextStyle(color: c.textMid, fontSize: 11.5)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(details, style: TextStyle(color: c.textSoft, fontSize: 12)),
              ],
            ),
          ),
          if (r.cost != null) ...[
            const SizedBox(width: 8),
            Text('${r.costEstimated ? '≈ ' : ''}${Fmt.money(r.cost!)}', style: TextStyle(color: c.ok, fontWeight: FontWeight.w800, fontSize: 14.5)),
          ],
          if (onDelete != null)
            IconButton(
              tooltip: 'Eliminar registro',
              icon: Icon(Icons.delete_outline, color: c.textSoft, size: 20),
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
