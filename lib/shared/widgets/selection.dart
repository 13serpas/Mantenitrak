import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tarjeta seleccionable (tipo de vehículo, rol, zona…).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.compact = false,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Centrado y sin subtítulo (rejilla de tipos).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      selected: selected,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected ? primary.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? primary : c.border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 14),
            child: compact
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? primary : c.textMid,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: selected ? primary : null,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: TextStyle(color: c.textMid, fontSize: 12.5, height: 1.35)),
                            ],
                          ],
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle, color: primary, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Grupo de opciones cortas en una fila que se parte en varias líneas.
class ChoicePills extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allowDeselect = true,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  /// Pulsar la opción ya elegida la quita (campos opcionales).
  final bool allowDeselect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: o == selected,
            onSelected: (on) => onSelected(on ? o : (allowDeselect ? '' : o)),
          ),
      ],
    );
  }
}
