import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/selection.dart';
import '../../../domain/vehicle.dart';
import '../../providers/add_vehicle_controller.dart';
import '../widgets/step_header.dart';

class TypeStep extends ConsumerWidget {
  const TypeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(addVehicleControllerProvider.select((s) => s.draft.type));
    final controller = ref.read(addVehicleControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Qué tipo de vehículo es?',
          subtitle: 'El plan de mantenimiento se adapta a cada tipo.',
        ),
        LayoutBuilder(builder: (context, constraints) {
          final columns = (constraints.maxWidth / 120).floor().clamp(3, 5);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final t in VehicleType.values)
                OptionCard(
                  compact: true,
                  emoji: t.emoji,
                  title: t.label,
                  selected: selected == t,
                  onTap: () => controller.selectType(t),
                ),
            ],
          );
        }),
      ],
    );
  }
}
