import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tarjeta base: borde fino, esquinas de 14 y efecto al pulsar.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  /// Si se indica, sustituye a la lectura del contenido por lectores de pantalla.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    Widget card = Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? context.colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (semanticLabel != null) {
      card = Semantics(
        label: semanticLabel,
        button: onTap != null,
        excludeSemantics: true,
        child: card,
      );
    }
    return card;
  }
}
