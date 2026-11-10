import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/utils/formatters.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/message_banner.dart';
import '../../../../../shared/widgets/status_badge.dart';
import '../../../domain/vehicle_draft.dart';
import '../../providers/add_vehicle_controller.dart';
import '../../widgets/specs_form.dart';
import '../widgets/step_header.dart';

class SpecsStep extends ConsumerWidget {
  const SpecsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addVehicleControllerProvider);
    final controller = ref.read(addVehicleControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Revisa y añade',
          subtitle: 'La ficha técnica es opcional: puedes completarla más tarde.',
        ),
        _Summary(draft: state.draft),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('Ficha técnica', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (state.specsStatus == SpecsStatus.ready)
              TextButton.icon(
                onPressed: controller.clearSpecs,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        switch (state.specsStatus) {
          SpecsStatus.none => _SpecsChooser(
              onAi: controller.generateSpecs,
              onManual: controller.startManualSpecs,
            ),
          SpecsStatus.loading => const _SpecsLoading(),
          SpecsStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MessageBanner(message: state.specsError ?? 'No se pudo generar la ficha.'),
                const SizedBox(height: 12),
                _SpecsChooser(
                  aiLabel: 'Reintentar con IA',
                  onAi: controller.generateSpecs,
                  onManual: controller.startManualSpecs,
                ),
              ],
            ),
          SpecsStatus.ready => SpecsForm(
              specs: state.specs!,
              type: state.draft.type,
              electric: state.draft.isElectric,
              diesel: state.draft.isDiesel,
              onChanged: controller.setSpec,
            ),
        },
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.draft});

  final VehicleDraft draft;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final km = int.tryParse(draft.currentKm);
    final roleLabel = switch (draft.role) {
      'regular' => 'Usuario habitual',
      'company' => 'Empresa',
      'mechanic' => 'Taller',
      _ => 'Propietario',
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.type?.emoji ?? '🚘', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  [
                    draft.year,
                    if (draft.engine.trim().isNotEmpty) draft.engine.trim(),
                    if (draft.plate.trim().isNotEmpty) draft.plate.trim().toUpperCase(),
                  ].join(' · '),
                  style: TextStyle(color: c.textMid, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (km != null) InfoChip(label: '📍 ${Fmt.km(km)}'),
                    if (draft.fuelType.isNotEmpty) InfoChip(label: '⛽ ${draft.fuelType}'),
                    if (draft.usage.isNotEmpty) InfoChip(label: '🛣️ ${draft.usage}'),
                    InfoChip(label: '👤 $roleLabel'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecsChooser extends StatelessWidget {
  const _SpecsChooser({required this.onAi, required this.onManual, this.aiLabel = 'Generar con IA'});

  final VoidCallback onAi;
  final VoidCallback onManual;
  final String aiLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aceite, filtros, neumáticos y batería: lo que necesitas al ir al taller o comprar recambios.',
          style: TextStyle(color: context.colors.textMid, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        AppButton(label: '🤖  $aiLabel', onPressed: onAi),
        const SizedBox(height: 8),
        AppButton(label: 'Rellenar a mano', variant: AppButtonVariant.outline, onPressed: onManual),
      ],
    );
  }
}

class _SpecsLoading extends StatelessWidget {
  const _SpecsLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Consultando la ficha técnica',
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Consultando especificaciones…'),
            ],
          ),
        ),
      ),
    );
  }
}
