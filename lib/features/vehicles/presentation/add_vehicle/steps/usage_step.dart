import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/field_label.dart';
import '../../../../../shared/widgets/message_banner.dart';
import '../../../../../shared/widgets/selection.dart';
import '../../../domain/vehicle_draft.dart';
import '../../providers/add_vehicle_controller.dart';
import '../widgets/step_header.dart';

class UsageStep extends ConsumerWidget {
  const UsageStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(addVehicleControllerProvider.select((s) => s.draft));
    final controller = ref.read(addVehicleControllerProvider.notifier);
    final numbers = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepHeader(
          title: draft.usesKm ? '¿Cómo lo usas?' : 'Motor',
          subtitle: draft.usesKm
              ? 'Con esto calculamos cuándo toca cada revisión.'
              : 'En embarcaciones el mantenimiento se controla por tiempo.',
        ),
        if (draft.usesKm) ...[
          const FieldLabel('Kilometraje actual'),
          TextFormField(
            initialValue: draft.currentKm,
            keyboardType: TextInputType.number,
            inputFormatters: numbers,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => VehicleDraft.validateCurrentKm(v ?? ''),
            onChanged: (v) => controller.update((d) => d.copyWith(currentKm: v)),
            decoration: const InputDecoration(hintText: 'ej. 45000', suffixText: 'km'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Km al año (opcional)'),
          TextFormField(
            initialValue: draft.annualKm,
            keyboardType: TextInputType.number,
            inputFormatters: numbers,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => VehicleDraft.validateAnnualKm(v ?? ''),
            onChanged: (v) => controller.update((d) => d.copyWith(annualKm: v)),
            decoration: const InputDecoration(
              hintText: 'ej. 12000',
              suffixText: 'km/año',
              helperText: 'Si no lo sabes, déjalo vacío: lo calcularemos con tus lecturas.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 20),
        ],
        const FieldLabel('Combustible'),
        ChoicePills(
          options: draft.usesKm ? VehicleDraft.fuelTypes : VehicleDraft.boatFuelTypes,
          selected: draft.fuelType,
          onSelected: (v) => controller.update((d) => d.copyWith(fuelType: v)),
        ),
        if (draft.isElectric || draft.isDiesel) ...[
          const SizedBox(height: 12),
          MessageBanner(
            tone: BannerTone.info,
            message: draft.isElectric
                ? 'Al ser eléctrico no te pediremos aceite, filtros de combustible, bujías ni correa.'
                : 'Los diésel no llevan bujías: no aparecerán en tu plan.',
          ),
        ],
        if (draft.usesKm) ...[
          const SizedBox(height: 20),
          const FieldLabel('Uso principal'),
          ChoicePills(
            options: VehicleDraft.usages,
            selected: draft.usage,
            onSelected: (v) => controller.update((d) => d.copyWith(usage: v)),
          ),
          if (!draft.isElectric && (draft.usage == 'Ciudad' || draft.usage == 'Profesional')) ...[
            const SizedBox(height: 12),
            const MessageBanner(
              tone: BannerTone.info,
              message: 'Uso exigente: adelantaremos un 15 % los cambios de aceite.',
            ),
          ],
        ],
      ],
    );
  }
}
