import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Marcador para pantallas de la hoja de ruta aún no implementadas,
/// para que la navegación se pueda probar de punta a punta.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.roadmapStep});

  final String title;
  final String roadmapStep;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Pendiente: $roadmapStep de la hoja de ruta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMid),
          ),
        ),
      ),
    );
  }
}
