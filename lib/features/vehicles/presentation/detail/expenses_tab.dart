import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../expenses/domain/cost_summary.dart';
import '../../domain/vehicle_detail.dart';
import 'detail_widgets.dart';

/// Pestaña "Gastos": mantenimiento + combustible + otros gastos por periodo.
class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key, required this.detail, required this.onAddExpense});

  final VehicleDetail detail;
  final VoidCallback onAddExpense;

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  CostPeriod _period = CostPeriod.year;

  static const _otherColor = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    final d = widget.detail;
    final summary = CostSummary.compute(
      period: _period,
      maintenance: d.vehicle.maintenance,
      fuel: d.vehicle.fuelLogs,
      expenses: d.expenses,
      kmTravelled: d.kmTravelled,
    );

    return DetailTabScroll(
      storageKey: 'gastos',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in CostPeriod.values)
              ChoiceChip(
                label: Text(p.label),
                selected: p == _period,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gasto total ${_period.phrase}', style: TextStyle(color: c.textMid, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(Fmt.euros(summary.total),
                        style: TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 28)),
                  ],
                ),
              ),
              if (summary.costPerKm != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${Fmt.decimal(summary.costPerKm!, 2)} €/km',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('coste por km', style: TextStyle(color: c.textSoft, fontSize: 11)),
                  ],
                ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: StatBox(label: 'Mantenimiento', value: Fmt.euros(summary.maintenance), valueColor: primary)),
            const SizedBox(width: 8),
            Expanded(child: StatBox(label: 'Combustible', value: Fmt.euros(summary.fuel), valueColor: c.fuel)),
            const SizedBox(width: 8),
            Expanded(child: StatBox(label: 'Otros', value: Fmt.euros(summary.other), valueColor: _otherColor)),
          ],
        ),
        if (summary.isEmpty)
          EmptyTabMessage(
            emoji: '💶',
            title: 'Sin gastos ${_period.phrase}',
            body: 'Aquí se suman los costes de los mantenimientos, los repostajes y otros gastos '
                'como el seguro, la ITV o el parking.',
            actionLabel: 'Añadir gasto',
            onAction: widget.onAddExpense,
          ),
        if (summary.byCategory.isNotEmpty) ...[
          const TabSectionTitle('Otros gastos'),
          AppCard(
            child: Column(
              children: [
                for (final e in summary.categoriesSorted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(child: Text(e.key.icon, style: const TextStyle(fontSize: 16))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key.label)),
                            Text(
                              '${Fmt.euros(e.value)} · ${(e.value / summary.total * 100).round()} %',
                              style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: summary.total > 0 ? e.value / summary.total : 0,
                            minHeight: 5,
                            backgroundColor: c.surfaceAlt,
                            color: _otherColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (summary.months.any((m) => m.total > 0)) ...[
          const TabSectionTitle('Últimos 12 meses'),
          _MonthlyChart(months: summary.months, otherColor: _otherColor),
        ],
      ],
    );
  }
}

/// Barras apiladas por mes, sin dependencias de gráficos.
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months, required this.otherColor});

  final List<MonthCost> months;
  final Color otherColor;

  static const _letters = ['E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    final maxTotal = months.map((m) => m.total).fold<double>(0, math.max);
    const barArea = 110.0;

    Widget legend(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: c.textSoft, fontSize: 11)),
          ],
        );

    return AppCard(
      semanticLabel: 'Gasto mensual de los últimos 12 meses. Máximo ${Fmt.euros(maxTotal)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, children: [
            legend(primary, 'Mantenimiento'),
            legend(c.fuel, 'Combustible'),
            legend(otherColor, 'Otros'),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: barArea + 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(
                    child: Tooltip(
                      message: '${Fmt.date(m.month).substring(3)}: ${Fmt.euros(m.total)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _Bar(month: m, maxTotal: maxTotal, height: barArea, otherColor: otherColor),
                          const SizedBox(height: 4),
                          Text(_letters[m.month.month - 1], style: TextStyle(color: c.textSoft, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.month, required this.maxTotal, required this.height, required this.otherColor});

  final MonthCost month;
  final double maxTotal;
  final double height;
  final Color otherColor;

  @override
  Widget build(BuildContext context) {
    if (maxTotal <= 0 || month.total <= 0) return const SizedBox(height: 2);
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    double h(double v) => v / maxTotal * height;
    return Container(
      width: 14,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(3))),
      child: Column(
        children: [
          if (month.other > 0) Container(height: h(month.other), color: otherColor),
          if (month.fuel > 0) Container(height: h(month.fuel), color: c.fuel),
          if (month.maintenance > 0) Container(height: h(month.maintenance), color: primary),
        ],
      ),
    );
  }
}
