import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../fuel/domain/fuel_log.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../providers/vehicle_detail_provider.dart';
import 'detail_widgets.dart';

/// Pestaña "Combustible": gasto, cantidad, consumo medio y repostajes.
/// En eléctricos (o recargas de un enchufable) la cantidad son kWh.
class FuelTab extends ConsumerStatefulWidget {
  const FuelTab({super.key, required this.vehicle, required this.onAddFuel});

  final Vehicle vehicle;
  final VoidCallback onAddFuel;

  @override
  ConsumerState<FuelTab> createState() => _FuelTabState();
}

class _FuelTabState extends ConsumerState<FuelTab> {
  /// Un Dismissible deslizado debe salir del árbol en el mismo fotograma.
  final _removed = <String>{};

  Vehicle get _v => widget.vehicle;

  Future<bool> _confirmDelete(FuelLog f) => confirmDialog(
        context,
        title: f.isElectric ? 'Eliminar recarga' : 'Eliminar repostaje',
        message: '¿Seguro que quieres eliminar ${f.isElectric ? 'la recarga' : 'el repostaje'} del '
            '${Fmt.date(f.loggedAt)}${f.total != null ? ' (${Fmt.money(f.total!)})' : ''}?',
        confirmLabel: 'Eliminar',
        destructive: true,
      );

  Future<void> _delete(FuelLog f) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removed.add(f.id));
    try {
      await ref.read(vehicleActionsProvider).deleteFuelLog(_v.id, f);
      messenger.showSnackBar(SnackBar(content: Text(f.isElectric ? 'Recarga eliminada' : 'Repostaje eliminado')));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _removed.remove(f.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final userId = ref.watch(currentUserIdProvider);
    final logs = _v.fuelLogs.where((f) => !_removed.contains(f.id)).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final isElectric = (_v.fuelType ?? '').toLowerCase().contains('eléctric');

    if (logs.isEmpty) {
      return DetailTabScroll(
        storageKey: 'combustible',
        children: [
          EmptyTabMessage(
            emoji: isElectric ? '🔌' : '⛽',
            title: isElectric ? 'Sin recargas registradas' : 'Sin repostajes registrados',
            body: isElectric
                ? 'Anota cada recarga con los km y los kWh. Con dos cargas completas ya '
                    'podremos calcular tu consumo real.'
                : 'Anota cada repostaje con los km y los litros. Con dos depósitos llenos ya '
                    'podremos calcular tu consumo real.',
            actionLabel: isElectric ? 'Registrar recarga' : 'Registrar repostaje',
            onAction: widget.onAddFuel,
          ),
        ],
      );
    }

    final spend = logs.fold<double>(0, (s, f) => s + (f.total ?? 0));
    // La cantidad se suma en la misma unidad que el consumo (litros o kWh).
    final measured = FuelLog.forConsumption(logs);
    final quantity = measured.fold<double>(0, (s, f) => s + (f.liters ?? 0));
    final consumptionUnit = FuelLog.consumptionUnit(logs);
    final unit = consumptionUnit == 'L/100' ? 'L' : 'kWh';
    final avg = MaintenanceCalculator.averageConsumption(logs);
    final increase = MaintenanceCalculator.consumptionIncrease(logs);
    final thisYear = DateTime.now().year;
    final yearSpend = logs.where((f) => f.loggedAt.year == thisYear).fold<double>(0, (s, f) => s + (f.total ?? 0));
    final kmRange = _kmRange(logs);
    final perKm = kmRange != null && kmRange > 0 && spend > 0 ? spend / kmRange * 100 : null;

    return DetailTabScroll(
      storageKey: 'combustible',
      children: [
        Row(
          children: [
            Expanded(child: StatBox(label: 'Gasto total', value: spend > 0 ? Fmt.euros(spend) : '—', valueColor: c.fuel)),
            const SizedBox(width: 8),
            Expanded(child: StatBox(label: unit == 'L' ? 'Litros' : 'Energía', value: quantity > 0 ? '${Fmt.thousands(quantity)} $unit' : '—')),
            const SizedBox(width: 8),
            Expanded(
              child: StatBox(
                label: 'Consumo medio',
                value: avg != null ? '${Fmt.decimal(avg)} $consumptionUnit' : '—',
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: StatBox(label: 'Este año', value: Fmt.euros(yearSpend))),
            const SizedBox(width: 8),
            Expanded(child: StatBox(label: 'Coste cada 100 km', value: perKm != null ? Fmt.money(perKm) : '—')),
          ],
        ),
        if (avg == null)
          Text(
            unit == 'L'
                ? 'El consumo medio aparece cuando hay dos repostajes con el depósito lleno y los km.'
                : 'El consumo medio aparece cuando hay dos cargas completas con los km.',
            style: TextStyle(color: c.textSoft, fontSize: 12),
          ),
        if (increase != null)
          MessageBanner(
            tone: BannerTone.info,
            message: 'El último ${unit == 'L' ? 'depósito' : 'tramo'} ha gastado ${Fmt.decimal(increase.last)} '
                '$consumptionUnit, un ${increase.percentAbove} % más que tu media (${Fmt.decimal(increase.average)}). '
                'Revisa la presión de los neumáticos y el filtro de aire; si se repite, coméntalo en el taller.',
          ),
        TabSectionTitle(isElectric ? 'Recargas' : 'Repostajes'),
        for (final f in logs)
          f.userId != null && f.userId == userId
              ? Dismissible(
                  key: ValueKey(f.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(f),
                  onDismissed: (_) => _delete(f),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: _FuelRow(
                    log: f,
                    onDelete: () async {
                      if (await _confirmDelete(f)) await _delete(f);
                    },
                  ),
                )
              : _FuelRow(log: f),
      ],
    );
  }

  /// Km recorridos entre el primer y el último repostaje con km.
  static int? _kmRange(List<FuelLog> logs) {
    final kms = logs.map((f) => f.km).whereType<int>().toList();
    if (kms.length < 2) return null;
    kms.sort();
    return kms.last - kms.first;
  }
}

class _FuelRow extends StatelessWidget {
  const _FuelRow({required this.log, this.onDelete});

  final FuelLog log;

  /// Alternativa accesible al gesto de deslizar (solo los propios).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = log;
    final price = f.effectivePricePerLiter;
    final unit = f.isElectric ? 'kWh' : 'L';
    final details = [
      Fmt.date(f.loggedAt),
      if (f.km != null) Fmt.km(f.km!),
      if (f.liters != null) '${Fmt.decimal(f.liters!, 2)} $unit',
      if (price != null) '${Fmt.decimal(price, 3)} €/$unit',
      if (f.station != null) f.station!,
    ].join(' · ');
    final full = f.isElectric ? ' · Completa' : ' · Lleno';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${f.isElectric ? '🔌 Recarga' : (f.fuelType ?? 'Repostaje')}${f.fullTank ? full : ' · Parcial'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(details, style: TextStyle(color: c.textSoft, fontSize: 12)),
              ],
            ),
          ),
          if (f.total != null) ...[
            const SizedBox(width: 10),
            Text(Fmt.money(f.total!), style: TextStyle(color: c.fuel, fontWeight: FontWeight.w800, fontSize: 15)),
          ],
          if (onDelete != null)
            IconButton(
              tooltip: 'Eliminar',
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
