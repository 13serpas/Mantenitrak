import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/message_banner.dart';
import '../../../../../shared/widgets/selection.dart';
import '../../providers/add_vehicle_controller.dart';
import '../widgets/step_header.dart';

class RoleStep extends ConsumerWidget {
  const RoleStep({super.key});

  static const roles = [
    ('owner', '👑', 'Propietario', 'Es tuyo y llevas tú el mantenimiento.'),
    ('regular', '👤', 'Usuario habitual', 'Lo conduces tú, pero es de otra persona (familia, renting…).'),
    ('company', '🏢', 'Empresa', 'Forma parte de una flota de empresa.'),
    ('mechanic', '🔧', 'Taller / Mecánico', 'Lo gestionas para un cliente. Aparecerá en el modo taller.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(addVehicleControllerProvider.select((s) => s.draft.role));
    final controller = ref.read(addVehicleControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cuál es tu relación con el vehículo?',
          subtitle: 'Más adelante podrás compartirlo con otras personas.',
        ),
        for (final (id, emoji, title, desc) in roles) ...[
          OptionCard(
            emoji: emoji,
            title: title,
            subtitle: desc,
            selected: role == id,
            onTap: () => controller.update((d) => d.copyWith(role: id)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ZoneStep extends ConsumerWidget {
  const ZoneStep({super.key});

  static const zones = [
    ('interior', '🏙️', 'Interior', 'Meseta y ciudad. Condiciones estándar.'),
    ('costa', '🌊', 'Costa', 'Sal y humedad envejecen antes el caucho.'),
    ('montana', '🏔️', 'Montaña', 'Frío, nieve y curvas desgastan más.'),
    ('mixto', '🗺️', 'Mixto', 'Uso variado: vigila el desgaste desigual.'),
    ('norte', '🌧️', 'Norte húmedo', 'Lluvia frecuente: importa el drenaje.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(addVehicleControllerProvider.select((s) => s.draft.zone));
    final controller = ref.read(addVehicleControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Por dónde circula sobre todo?',
          subtitle: 'Ajusta la vida útil estimada de los neumáticos.',
        ),
        for (final (id, emoji, title, desc) in zones) ...[
          OptionCard(
            emoji: emoji,
            title: title,
            subtitle: desc,
            selected: zone == id,
            onTap: () => controller.update((d) => d.copyWith(zone: id)),
          ),
          const SizedBox(height: 10),
        ],
        if (zone == 'costa' || zone == 'montana') ...[
          const SizedBox(height: 4),
          const MessageBanner(
            tone: BannerTone.info,
            message: 'Te avisaremos antes de lo habitual para revisar los neumáticos (un 20 % antes, aprox.).',
          ),
        ],
      ],
    );
  }
}
