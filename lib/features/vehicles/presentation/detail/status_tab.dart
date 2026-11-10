import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../domain/vehicle.dart';
import 'detail_widgets.dart';

/// Pestaña "Estado": km y todos los elementos del plan, por categorías.
class StatusTab extends StatelessWidget {
  const StatusTab({
    super.key,
    required this.vehicle,
    required this.health,
    required this.onUpdateKm,
  });

  final Vehicle vehicle;
  final VehicleHealth health;
  final VoidCallback onUpdateKm;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<ItemState>>{};
    for (final s in health.states) {
      byCategory.putIfAbsent(s.item.category, () => []).add(s);
    }

    return DetailTabScroll(
      storageKey: 'estado',
      children: [
        if (vehicle.type != VehicleType.barco)
          _KmCard(vehicle: vehicle, health: health, onUpdate: onUpdateKm)
        else
          AppCard(
            child: Text(
              '⛵ En embarcaciones el mantenimiento se controla por tiempo, no por kilómetros.',
              style: TextStyle(color: context.colors.textMid, height: 1.4),
            ),
          ),
        for (final entry in byCategory.entries) ...[
          TabSectionTitle(entry.key),
          for (final s in entry.value) _ItemCard(state: s, zone: vehicle.zone),
        ],
      ],
    );
  }
}

class _KmCard extends StatelessWidget {
  const _KmCard({required this.vehicle, required this.health, required this.onUpdate});

  final Vehicle vehicle;
  final VehicleHealth health;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final readings = vehicle.kmLogs.length;
    return AppCard(
      onTap: onUpdate,
      semanticLabel: 'Kilometraje: ${vehicle.currentKm != null ? Fmt.km(vehicle.currentKm!) : 'sin registrar'}. '
          'Pulsa para actualizarlo.',
      child: Row(
        children: [
          const ExcludeSemantics(child: Text('📍', style: TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.currentKm != null ? Fmt.km(vehicle.currentKm!) : 'Sin kilometraje',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.km(health.annualKm)}/año ${health.annualKmIsMeasured ? 'según tus lecturas' : 'estimados'}'
                  ' · ${plural(readings, 'lectura', 'lecturas')}',
                  style: TextStyle(color: c.textMid, fontSize: 12.5),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUpdate, child: const Text('Actualizar')),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.state, required this.zone});

  final ItemState state;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = state;
    final last = s.lastRecord;
    final next = [
      if (s.nextKm != null) Fmt.km(s.nextKm!),
      if (s.nextDate != null) Fmt.date(s.nextDate),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Text(s.item.icon, style: const TextStyle(fontSize: 18))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              ),
              StatusBadge(label: s.status.label, tone: s.status.tone),
            ],
          ),
          const SizedBox(height: 10),
          IntervalBar(progress: s.progress, status: s.status),
          if (s.item.id == 'neumaticos' && zone != 'interior') ...[
            const SizedBox(height: 8),
            _ZoneNote(zone: zone),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  last == null
                      ? 'Sin registrar aún'
                      : 'Último: ${Fmt.date(last.performedAt)}${last.km != null ? ' · ${Fmt.km(last.km!)}' : ''}',
                  style: TextStyle(color: c.textSoft, fontSize: 11.5),
                ),
              ),
              if (next.isNotEmpty)
                Text('Próximo: $next', style: TextStyle(color: c.textSoft, fontSize: 11.5)),
            ],
          ),
          if (s.hint != null) ...[
            const SizedBox(height: 4),
            Text(s.hint!, style: TextStyle(color: c.textMid, fontSize: 11.5, height: 1.35)),
          ] else if (s.status == ItemStatus.unknown && last == null) ...[
            const SizedBox(height: 4),
            Text(
              _intervalText(s),
              style: TextStyle(color: c.textSoft, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  static String _intervalText(ItemState s) {
    final km = s.item.intervalKm;
    final mo = s.item.intervalMonths;
    final parts = [
      if (km != null) 'cada ${Fmt.km(km)}',
      if (mo != null) mo % 12 == 0 ? 'cada ${plural(mo ~/ 12, 'año', 'años')}' : 'cada $mo meses',
    ];
    return 'Recomendado ${parts.join(' o ')}${parts.length > 1 ? ' (lo que llegue antes)' : ''}.';
  }
}

class _ZoneNote extends StatelessWidget {
  const _ZoneNote({required this.zone});

  final String zone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, text) = switch (zone) {
      'costa' => ('🌊', 'Sal y humedad envejecen antes el caucho: te avisamos antes.'),
      'montana' => ('🏔️', 'Frío, nieve y curvas desgastan más: te avisamos antes.'),
      'norte' => ('🌧️', 'Con lluvia frecuente, vigila el dibujo y el drenaje.'),
      _ => ('🗺️', 'Uso variado: revisa que el desgaste sea parejo entre ejes.'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.warningBorder),
      ),
      child: Text('$icon $text', style: TextStyle(color: c.warning, fontSize: 12)),
    );
  }
}
