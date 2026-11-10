import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';

/// Contenido desplazable de una pestaña del detalle.
///
/// Usa el patrón de [NestedScrollView] con `SliverOverlapInjector` para que
/// la barra de pestañas fijada arriba no tape el principio de la lista.
class DetailTabScroll extends StatelessWidget {
  const DetailTabScroll({
    super.key,
    required this.storageKey,
    required this.children,
    this.bottomPadding = 96,
  });

  final String storageKey;
  final List<Widget> children;

  /// Hueco para que el botón flotante no tape el último elemento.
  final double bottomPadding;

  static const maxWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
        builder: (context) => CustomScrollView(
          key: PageStorageKey(storageKey),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.crossAxisExtent - maxWidth) / 2).clamp(16.0, double.infinity);
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(side, 16, side, bottomPadding),
                  sliver: SliverList.separated(
                    itemCount: children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => children[i],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío dentro de una pestaña.
class EmptyTabMessage extends StatelessWidget {
  const EmptyTabMessage({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 44))),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textMid, height: 1.5)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            AppButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Dato con etiqueta pequeña (cabecera y resúmenes).
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textSoft, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progreso del intervalo de un mantenimiento.
class IntervalBar extends StatelessWidget {
  const IntervalBar({super.key, required this.progress, required this.status});

  final double progress;
  final ItemStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (status) {
      ItemStatus.danger => c.danger,
      ItemStatus.warning => c.warning,
      ItemStatus.ok => c.ok,
      ItemStatus.unknown => c.border,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: status == ItemStatus.unknown ? 0 : progress.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: c.surfaceAlt,
        color: color,
      ),
    );
  }
}

/// Título de sección dentro de una pestaña.
class TabSectionTitle extends StatelessWidget {
  const TabSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
