import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../providers/vehicles_provider.dart';

/// Hoja inferior para registrar el kilometraje actual.
class KmUpdateSheet extends ConsumerStatefulWidget {
  const KmUpdateSheet({super.key, required this.vehicle});

  final Vehicle vehicle;

  /// Devuelve true si se ha guardado.
  static Future<bool?> show(BuildContext context, Vehicle vehicle) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => KmUpdateSheet(vehicle: vehicle),
      );

  @override
  ConsumerState<KmUpdateSheet> createState() => _KmUpdateSheetState();
}

class _KmUpdateSheetState extends ConsumerState<KmUpdateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _km = TextEditingController();
  bool _saving = false;
  String? _error;

  /// Por encima de esto, casi seguro que es un error al teclear.
  static const _maxJump = 200000;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final km = int.tryParse((value ?? '').replaceAll('.', '').trim());
    if (km == null) return 'Introduce los km que marca el cuentakilómetros';
    final current = widget.vehicle.currentKm;
    if (current != null && km < current) {
      return 'No puede ser menor que el último registro (${Fmt.km(current)})';
    }
    if (current != null && km - current > _maxJump) {
      return 'Son más de ${Fmt.km(_maxJump)} desde la última lectura. ¿Está bien escrito?';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final km = int.parse(_km.text.replaceAll('.', '').trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(vehiclesProvider.notifier).logKm(widget.vehicle.id, km);
      if (mounted) Navigator.of(context).pop(true);
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final colors = context.colors;
    final (annual, measured) = MaintenanceCalculator.annualKm(v);
    final recent = ([...v.kmLogs]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt))).take(3);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actualizar kilometraje',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${v.type.emoji} ${v.displayName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMid),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _km,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: _validate,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
              decoration: InputDecoration(
                hintText: v.currentKm != null ? Fmt.thousands(v.currentKm!) : 'ej. 45000',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: measured ? colors.okLight : colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: measured ? colors.okBorder : colors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          measured ? 'Km/año según tus lecturas' : 'Km/año estimados',
                          style: TextStyle(color: colors.textMid, fontSize: 12),
                        ),
                      ),
                      Text(
                        Fmt.km(annual),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: measured ? colors.ok : colors.textMid,
                        ),
                      ),
                    ],
                  ),
                  for (final log in recent) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(Fmt.date(log.loggedAt),
                              style: TextStyle(color: colors.textSoft, fontSize: 12)),
                        ),
                        Text(Fmt.km(log.km),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            AppButton(label: 'Guardar', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
