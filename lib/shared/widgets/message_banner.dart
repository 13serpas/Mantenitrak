import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum BannerTone { error, success, info }

/// Aviso en línea (errores de formulario, confirmaciones), con acción opcional.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.error,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color border, Color fg, IconData icon) = switch (tone) {
      BannerTone.error => (c.dangerLight, c.dangerBorder, c.danger, Icons.error_outline),
      BannerTone.success => (c.okLight, c.okBorder, c.ok, Icons.check_circle_outline),
      BannerTone.info => (
          c.surfaceAlt,
          c.border,
          Theme.of(context).colorScheme.primary,
          Icons.info_outline
        ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: fg, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
