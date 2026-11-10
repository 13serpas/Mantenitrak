import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_specs.dart';

/// Campos editables de la ficha técnica. Lo usan el asistente de alta y la
/// pestaña "Ficha" del detalle.
class SpecsForm extends StatelessWidget {
  const SpecsForm({
    super.key,
    required this.specs,
    required this.type,
    required this.electric,
    required this.diesel,
    required this.onChanged,
    this.generation = 0,
  });

  final VehicleSpecs specs;
  final VehicleType? type;
  final bool electric;
  final bool diesel;
  final void Function(String key, String value) onChanged;

  /// Cambia cada vez que llega una ficha nueva (p. ej. regenerada por IA)
  /// para que los campos se reinicien con los valores nuevos.
  final int generation;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fields = VehicleSpecs.fieldsFor(type: type, electric: electric, diesel: diesel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (specs.source.isAutomatic) ...[
          const MessageBanner(
            tone: BannerTone.info,
            message: 'Datos orientativos generados por IA. Compruébalos en el manual o con tu '
                'taller antes de comprar recambios. Puedes corregir cualquier campo.',
          ),
          const SizedBox(height: 12),
        ],
        if (specs.oilBrands.isNotEmpty) ...[
          Text('Marcas de aceite sugeridas: ${specs.oilBrands.join(', ')}',
              style: TextStyle(color: c.textMid, fontSize: 12.5)),
          const SizedBox(height: 12),
        ],
        for (final f in fields) ...[
          TextFormField(
            key: ValueKey('$generation-${specs.source.name}-${f.key}'),
            initialValue: specs.valueOf(f.key),
            keyboardType: f.numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => VehicleSpecs.validateField(f, v ?? ''),
            onChanged: (v) => onChanged(f.key, v),
            decoration: InputDecoration(
              labelText: '${f.icon}  ${f.label}',
              hintText: f.hint,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
