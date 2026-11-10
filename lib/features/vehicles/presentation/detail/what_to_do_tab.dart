import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../../maintenance/domain/maintenance_help.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../domain/vehicle.dart';
import 'detail_widgets.dart';

/// Pestaña "¿Qué hacer?": lo urgente, explicado sin tecnicismos.
class WhatToDoTab extends StatefulWidget {
  const WhatToDoTab({
    super.key,
    required this.vehicle,
    required this.health,
    required this.onRegisterMaintenance,
  });

  final Vehicle vehicle;
  final VehicleHealth health;
  /// Abre «Registrar mantenimiento» con estos trabajos ya marcados.
  final void Function(List<String> itemIds) onRegisterMaintenance;

  @override
  State<WhatToDoTab> createState() => _WhatToDoTabState();
}

class _WhatToDoTabState extends State<WhatToDoTab> {
  String? _expanded;

  /// Texto para pegar en un mensaje al taller.
  String _workshopList(List<ItemState> urgent) {
    final v = widget.vehicle;
    final lines = [
      '${v.displayName}${v.plate != null ? ' (${v.plate})' : ''}'
          '${v.currentKm != null ? ' · ${Fmt.km(v.currentKm!)}' : ''}',
      'Revisar:',
      for (final s in urgent) '- ${s.item.name} (${s.status.label.toLowerCase()})',
    ];
    return lines.join('\n');
  }

  Future<void> _copy(List<ItemState> urgent) async {
    await Clipboard.setData(ClipboardData(text: _workshopList(urgent)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista copiada. Pégala en un mensaje a tu taller.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.health;
    final urgent = h.alerts;
    final unknown = h.count(ItemStatus.unknown);
    final known = h.states.length - unknown;

    if (urgent.isEmpty) {
      return DetailTabScroll(
        storageKey: 'que-hacer',
        children: [
          if (known == 0)
            EmptyTabMessage(
              emoji: '📋',
              title: 'Aún no hay mantenimientos registrados',
              body: 'Registra lo último que le hicieron (aceite, ITV, neumáticos…) y te diremos '
                  'qué toca y cuándo.',
              actionLabel: 'Registrar mantenimiento',
              onAction: () => widget.onRegisterMaintenance(const []),
            )
          else
            EmptyTabMessage(
              emoji: '🟢',
              title: 'Todo en orden',
              body: unknown == 0
                  ? 'No hay revisiones pendientes. Buen trabajo manteniendo el vehículo al día.'
                  : 'Nada urgente en lo registrado. Hay ${plural(unknown, 'elemento', 'elementos')} '
                      'sin registrar: añádelos para que el aviso sea completo.',
            ),
        ],
      );
    }

    final anyDanger = urgent.any((s) => s.status == ItemStatus.danger);
    final c = context.colors;
    final (bg, fg, border) = StatusBadge.toneColors(context, anyDanger ? BadgeTone.danger : BadgeTone.warning);

    return DetailTabScroll(
      storageKey: 'que-hacer',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  anyDanger ? '🔴 Revisión urgente' : '🟡 Próximas revisiones',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 4),
              Text('Toca cada elemento para saber qué es y qué hacer.',
                  style: TextStyle(color: c.textMid, fontSize: 13)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => widget.onRegisterMaintenance([for (final s in urgent) s.item.id]),
                  style: TextButton.styleFrom(foregroundColor: fg, padding: EdgeInsets.zero),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(urgent.length == 1 ? 'Ya está hecho: registrarlo' : 'Ya están hechos: registrarlos'),
                ),
              ),
            ],
          ),
        ),
        for (final s in urgent)
          _UrgentItem(
            state: s,
            expanded: _expanded == s.item.id,
            onToggle: () => setState(() => _expanded = _expanded == s.item.id ? null : s.item.id),
            onDone: () => widget.onRegisterMaintenance([s.item.id]),
          ),
        AppCard(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 Consejo',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Lleva esta lista a tu taller y pide que revisen exactamente estos puntos. '
                'Después, regístralo aquí para que los avisos se reinicien.',
                style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _copy(urgent),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar lista para el taller'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UrgentItem extends StatelessWidget {
  const _UrgentItem({required this.state, required this.expanded, required this.onToggle, required this.onDone});

  final ItemState state;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDone;

  String get _action {
    final s = state;
    final danger = s.status == ItemStatus.danger;
    final parts = [
      if (s.nextKm != null) '${danger ? 'tocaba' : 'toca'} a los ${Fmt.km(s.nextKm!)}',
      if (s.nextDate != null) '${danger ? 'venció el' : 'vence el'} ${Fmt.date(s.nextDate)}',
    ];
    final when = parts.isEmpty ? '' : ': ${parts.join(' o ')}';
    return danger ? '👉 Hazlo cuanto antes$when.' : '👉 Prográmalo pronto$when.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = state;
    final (_, fg, border) = StatusBadge.toneColors(context, s.status.tone);

    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: border,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Text(s.item.icon, style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        s.lastRecord != null ? 'Último: ${Fmt.date(s.lastRecord!.performedAt)}' : 'Nunca registrado',
                        style: TextStyle(color: c.textSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: s.status.label, tone: s.status.tone),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: c.textMid),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('¿Qué es esto?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c.textMid)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                child: Text(MaintenanceHelp.of(s.item.id),
                    style: TextStyle(color: c.textMid, fontSize: 13, height: 1.5)),
              ),
              const SizedBox(height: 8),
              Text(_action, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Ya está hecho'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
