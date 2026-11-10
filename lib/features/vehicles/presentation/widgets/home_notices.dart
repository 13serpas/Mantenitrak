import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../domain/vehicle.dart';
import '../providers/vehicles_provider.dart';

/// "Necesitan atención": las revisiones más urgentes de todos los vehículos.
class AlertsCard extends StatelessWidget {
  const AlertsCard({super.key, required this.alerts, required this.onOpenVehicle});

  final List<VehicleAlert> alerts;
  final void Function(Vehicle) onOpenVehicle;

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = alerts.take(_maxShown).toList();
    final hidden = alerts.length - shown.length;

    return AppCard(
      color: c.dangerLight,
      borderColor: c.dangerBorder,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '⚠️ Necesitan atención',
              style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 4),
          for (final a in shown)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpenVehicle(a.vehicle),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 0),
                child: Row(
                  children: [
                    Text(a.state.item.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: a.state.item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' · ${a.vehicle.displayName}',
                            style: TextStyle(color: c.textMid),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(label: a.state.status.label, tone: a.state.status.tone),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                'y ${plural(hidden, 'aviso más', 'avisos más')}',
                style: TextStyle(color: c.textMid, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Recordatorio de anotar los km si hace más de 30 días de la última lectura.
class KmReminderCard extends StatelessWidget {
  const KmReminderCard({super.key, required this.vehicles, required this.onUpdate});

  final List<Vehicle> vehicles;
  final void Function(Vehicle) onUpdate;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final c = context.colors;
    return AppCard(
      color: primary.withValues(alpha: 0.06),
      borderColor: primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '📍 Anota el kilometraje',
              style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hace más de un mes sin lectura. Con los km al día, los avisos son más precisos.',
            style: TextStyle(color: c.textMid, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in vehicles)
                ActionChip(
                  avatar: Text(v.type.emoji),
                  label: Text(v.displayName),
                  tooltip: 'Actualizar km de ${v.displayName}',
                  onPressed: () => onUpdate(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
