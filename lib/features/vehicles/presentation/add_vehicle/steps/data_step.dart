import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/widgets/field_label.dart';
import '../../../domain/vehicle.dart';
import '../../../domain/vehicle_catalog.dart';
import '../../../domain/vehicle_draft.dart';
import '../../providers/add_vehicle_controller.dart';
import '../widgets/catalog_field.dart';
import '../widgets/step_header.dart';

class DataStep extends ConsumerWidget {
  const DataStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(addVehicleControllerProvider.select((s) => s.draft));
    final controller = ref.read(addVehicleControllerProvider.notifier);
    final type = draft.type;
    final isBoat = type == VehicleType.barco;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Datos del vehículo',
          subtitle: 'Elige de la lista o escribe lo que ponga en la documentación.',
        ),
        CatalogField(
          label: 'Marca',
          hint: switch (type) {
            VehicleType.moto => 'ej. Yamaha',
            VehicleType.camion => 'ej. Volvo',
            VehicleType.barco => 'ej. Beneteau',
            _ => 'ej. Seat',
          },
          initialValue: draft.brand,
          options: VehicleCatalog.brands(type),
          validator: (v) => VehicleDraft.validateRequired(v ?? '', 'la marca'),
          onChanged: (v) => controller.update((d) => d.withBrand(v)),
        ),
        const SizedBox(height: 16),
        // La clave depende de la marca: al cambiarla, el campo se recrea vacío.
        CatalogField(
          key: ValueKey('model-${draft.brand.toLowerCase()}'),
          label: 'Modelo',
          hint: isBoat ? 'ej. Flyer 7' : 'ej. Ibiza',
          initialValue: draft.model,
          options: VehicleCatalog.models(type, draft.brand),
          validator: (v) => VehicleDraft.validateRequired(v ?? '', 'el modelo'),
          onChanged: (v) => controller.update((d) => d.withModel(v)),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Año'),
                  TextFormField(
                    initialValue: draft.year,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) => VehicleDraft.validateYear(v ?? ''),
                    onChanged: (v) => controller.update((d) => d.copyWith(year: v)),
                    decoration: const InputDecoration(hintText: 'ej. 2019'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(isBoat ? 'Matrícula / folio (opcional)' : 'Matrícula (opcional)'),
                  TextFormField(
                    initialValue: draft.plate,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    onChanged: (v) => controller.update((d) => d.copyWith(plate: v)),
                    decoration: const InputDecoration(hintText: 'ej. 4521 HJK'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CatalogField(
          key: ValueKey('engine-${draft.brand.toLowerCase()}-${draft.model.toLowerCase()}'),
          label: 'Motorización (opcional)',
          hint: isBoat ? 'ej. Mercury 150 CV' : 'ej. 1.0 TSI 110 CV',
          initialValue: draft.engine,
          options: VehicleCatalog.engines(draft.brand, draft.model, type: type),
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onChanged: (v) => controller.update((d) => d.copyWith(engine: v)),
        ),
        const SizedBox(height: 8),
        Text(
          'Con la motorización exacta, la ficha técnica será más precisa.',
          style: TextStyle(color: context.colors.textSoft, fontSize: 12),
        ),
      ],
    );
  }
}
