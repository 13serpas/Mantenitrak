import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum BadgeTone { ok, warning, danger, fuel, info, neutral }

/// Pastilla de color con texto corto ("2 vencidos", "Al día"…).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// (fondo, texto, borde) — también lo usan otros widgets de estado.
  static (Color, Color, Color) toneColors(BuildContext context, BadgeTone tone) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    return switch (tone) {
      BadgeTone.ok => (c.okLight, c.ok, c.okBorder),
      BadgeTone.warning => (c.warningLight, c.warning, c.warningBorder),
      BadgeTone.danger => (c.dangerLight, c.danger, c.dangerBorder),
      BadgeTone.fuel => (c.fuelLight, c.fuel, c.fuelBorder),
      BadgeTone.info => (primary.withValues(alpha: 0.08), primary, primary.withValues(alpha: 0.25)),
      BadgeTone.neutral => (c.surfaceAlt, c.textMid, c.border),
    };
  }
}

/// Dato pequeño con icono ("📍 45.000 km").
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = StatusBadge.toneColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
    );
  }
}
