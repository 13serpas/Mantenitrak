import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../domain/vehicle.dart';

/// Resumen de un vehículo en la pantalla de inicio.
class VehicleHealthCard extends StatelessWidget {
  const VehicleHealthCard({
    super.key,
    required this.vehicle,
    required this.health,
    this.onTap,
  });

  final Vehicle vehicle;
  final VehicleHealth health;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final h = health;
    final colors = context.colors;
    final pct = h.healthPercent;

    final (BadgeTone tone, String icon, String message) = h.danger > 0
        ? (BadgeTone.danger, '🔴', 'Atención: ${plural(h.danger, 'revisión vencida', 'revisiones vencidas')}')
        : h.warning > 0
            ? (BadgeTone.warning, '🟡', '${plural(h.warning, 'revisión', 'revisiones')} próximamente')
            : pct != null
                ? (BadgeTone.ok, '🟢', 'Todo en orden')
                : (BadgeTone.neutral, '⚪', 'Registra los mantenimientos para ver su estado');
    final (bannerBg, bannerFg, bannerBorder) = StatusBadge.toneColors(context, tone);

    final semantic = [
      '${v.type.label} ${v.displayName}',
      if (v.subtitle.isNotEmpty) v.subtitle,
      message,
      if (pct != null) 'Salud $pct por ciento',
      if (v.currentKm != null) Fmt.km(v.currentKm!),
      if (!v.isOwner) 'Compartido contigo como ${v.accessRole.label}',
    ].join('. ');

    return AppCard(
      onTap: onTap,
      semanticLabel: semantic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.type.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    if (v.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        v.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMid, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (pct != null) _HealthScore(percent: pct),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bannerBorder),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: bannerFg, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              InfoChip(label: '📍 ${v.currentKm != null ? Fmt.km(v.currentKm!) : 'Sin km'}'),
              if (h.averageConsumption != null)
                InfoChip(
                  label: '${h.consumptionUnit == 'L/100' ? '⛽' : '🔌'} '
                      '${Fmt.decimal(h.averageConsumption!)} ${h.consumptionUnit}',
                  tone: BadgeTone.fuel,
                ),
              if (v.hasSpecs) const InfoChip(label: '📄 Ficha técnica', tone: BadgeTone.ok),
              if (v.isOwner && v.ownerRole != 'owner')
                InfoChip(
                  label: switch (v.ownerRole) {
                    'regular' => '👤 Usuario habitual',
                    'company' => '🏢 Empresa',
                    'mechanic' => '🔧 Taller',
                    _ => '👑 Propietario',
                  },
                ),
              if (!v.isOwner)
                InfoChip(label: '🔗 ${v.accessRole.label}', tone: BadgeTone.info)
              else if (v.sharedCount > 0)
                InfoChip(label: '👥 ${plural(v.sharedCount, 'persona', 'personas')}', tone: BadgeTone.info),
            ],
          ),
          if (h.danger + h.warning + h.ok > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (h.danger > 0)
                  StatusBadge(label: plural(h.danger, 'vencido', 'vencidos'), tone: ItemStatus.danger.tone),
                if (h.warning > 0)
                  StatusBadge(label: plural(h.warning, 'próximo', 'próximos'), tone: ItemStatus.warning.tone),
                if (h.ok > 0) StatusBadge(label: '${h.ok} al día', tone: ItemStatus.ok.tone),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthScore extends StatelessWidget {
  const _HealthScore({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = percent > 70 ? c.ok : (percent > 40 ? c.warning : c.danger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$percent%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: color)),
        Text('salud', style: TextStyle(color: c.textSoft, fontSize: 11)),
      ],
    );
  }
}

/// Tarjeta de carga con la misma silueta que [VehicleHealthCard].
class VehicleHealthCardSkeleton extends StatelessWidget {
  const VehicleHealthCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: SkeletonPulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 36, height: 36, radius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 10),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            SkeletonBox(height: 36, radius: 10),
            SizedBox(height: 10),
            Row(
              children: [
                SkeletonBox(width: 90, height: 22),
                SizedBox(width: 6),
                SkeletonBox(width: 80, height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
