import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Diálogo de confirmación. Devuelve true solo si el usuario confirma.
/// (El prototipo lo declaraba en `shared_widgets` pero nunca lo definía.)
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? TextButton.styleFrom(foregroundColor: context.colors.danger) : null,
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}
