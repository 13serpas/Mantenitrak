import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../maintenance/domain/maintenance_calculator.dart';
import '../../../maintenance/presentation/status_tone.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_detail.dart';
import '../providers/vehicle_detail_provider.dart';
import '../widgets/km_update_sheet.dart';
import 'detail_widgets.dart';
import 'expenses_tab.dart';
import 'fuel_tab.dart';
import 'history_tab.dart';
import 'specs_tab.dart';
import 'status_tab.dart';
import 'what_to_do_tab.dart';

/// Pestañas del detalle. `slug` es el valor de `?tab=` en la ruta.
enum DetailTab {
  status('estado', 'Estado'),
  whatToDo('que-hacer', '¿Qué hacer?'),
  fuel('combustible', 'Combustible'),
  expenses('gastos', 'Gastos'),
  history('historial', 'Historial'),
  specs('ficha', 'Ficha');

  const DetailTab(this.slug, this.label);
  final String slug;
  final String label;

  static DetailTab parse(String? slug) =>
      values.firstWhere((t) => t.slug == slug, orElse: () => status);
}

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId, this.initialTab});

  final String vehicleId;
  final String? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vehicleDetailProvider(vehicleId));

    return detail.when(
      loading: () => const _LoadingView(),
      error: (e, _) => _MessageScaffold(
        emoji: '😕',
        title: 'No se ha podido cargar el vehículo',
        body: e is DataFailure ? e.message : 'Ha ocurrido un error inesperado.',
        actionLabel: 'Reintentar',
        onAction: () => ref.invalidate(vehicleDetailProvider(vehicleId)),
      ),
      data: (d) => d == null
          ? _MessageScaffold(
              emoji: '🔍',
              title: 'Este vehículo no está disponible',
              body: 'Puede que se haya eliminado o que ya no lo tengas compartido.',
              actionLabel: 'Volver al inicio',
              onAction: () => context.go(Routes.home),
            )
          : _DetailView(detail: d, initialTab: DetailTab.parse(initialTab)),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.detail, required this.initialTab});

  final VehicleDetail detail;
  final DetailTab initialTab;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: DetailTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );
  late DetailTab _current = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // El botón flotante depende de la pestaña: hay que reconstruir al
    // cambiar (en el prototipo no cambiaba).
    _tabs.addListener(() {
      final t = DetailTab.values[_tabs.index];
      if (t != _current) setState(() => _current = t);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Vehicle get _v => widget.detail.vehicle;

  Future<void> _updateKm() async {
    final saved = await KmUpdateSheet.show(context, _v);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kilometraje actualizado')));
    }
  }

  Future<void> _remove() async {
    final owner = _v.isOwner;
    final ok = await confirmDialog(
      context,
      title: owner ? 'Eliminar vehículo' : 'Dejar de ver este vehículo',
      message: owner
          ? 'Se borrarán ${_v.displayName} y todo su historial (mantenimientos, repostajes, gastos y '
              'accesos compartidos). No se puede deshacer.'
          : 'Dejarás de ver ${_v.displayName}. El propietario puede volver a compartirlo contigo.',
      confirmLabel: owner ? 'Eliminar' : 'Dejar de verlo',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(vehicleActionsProvider).removeVehicle(_v.id, isOwner: owner);
      router.go(Routes.home);
      messenger.showSnackBar(SnackBar(
        content: Text(owner ? '${_v.displayName} eliminado' : 'Ya no ves ${_v.displayName}'),
      ));
    } on DataFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _goTo(DetailTab t) => _tabs.animateTo(t.index);

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final health = MaintenanceCalculator.healthOf(v);
    final alerts = health.alerts.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(v.displayName, overflow: TextOverflow.ellipsis),
        actions: [
          if (v.isOwner)
            IconButton(
              tooltip: 'Editar vehículo',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.editVehicle(v.id)),
            ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              switch (value) {
                case 'share':
                  context.push(Routes.shareVehicle(v.id));
                case 'remove':
                  _remove();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'share', child: Text(v.isOwner ? 'Compartir' : 'Quién tiene acceso')),
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  v.isOwner ? 'Eliminar vehículo' : 'Dejar de ver este vehículo',
                  style: TextStyle(color: context.colors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _fab(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: _DetailHeader(
              detail: widget.detail,
              health: health,
              onAlerts: () => _goTo(DetailTab.whatToDo),
              onUpdateKm: _updateKm,
            ),
          ),
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
                  tabs: [
                    for (final t in DetailTab.values)
                      Tab(text: t == DetailTab.whatToDo && alerts > 0 ? '${t.label} ($alerts)' : t.label),
                  ],
                ),
                background: Theme.of(context).colorScheme.surface,
                border: context.colors.border,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            StatusTab(vehicle: v, health: health, onUpdateKm: _updateKm),
            WhatToDoTab(
              vehicle: v,
              health: health,
              onRegisterMaintenance: (items) => context.push(Routes.addMaintenance(v.id, items: items)),
            ),
            FuelTab(vehicle: v, onAddFuel: () => context.push(Routes.addFuel(v.id))),
            ExpensesTab(detail: widget.detail, onAddExpense: () => context.push(Routes.addExpense(v.id))),
            HistoryTab(vehicle: v, onRegisterMaintenance: () => context.push(Routes.addMaintenance(v.id))),
            SpecsTab(vehicle: v, specs: widget.detail.specs),
          ],
        ),
      ),
    );
  }

  Widget? _fab(BuildContext context) {
    final c = context.colors;
    final id = _v.id;
    final (String label, IconData icon, Color? color, String route)? cfg = switch (_current) {
      DetailTab.status ||
      DetailTab.whatToDo ||
      DetailTab.history =>
        ('Registrar mantenimiento', Icons.build_outlined, null, Routes.addMaintenance(id)),
      DetailTab.fuel => ('Registrar repostaje', Icons.local_gas_station_outlined, c.fuel, Routes.addFuel(id)),
      DetailTab.expenses => ('Añadir gasto', Icons.receipt_long_outlined, const Color(0xFF7C3AED), Routes.addExpense(id)),
      DetailTab.specs => null,
    };
    if (cfg == null) return null;
    final (label, icon, color, route) = cfg;
    return FloatingActionButton.extended(
      heroTag: 'detail-fab',
      onPressed: () => context.push(route),
      backgroundColor: color,
      foregroundColor: color == null ? null : Colors.white,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, {required this.background, required this.border});

  final TabBar tabBar;
  final Color background;
  final Color border;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background || old.border != border;
}

/// Cabecera: identidad del vehículo, salud, datos clave y avisos.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.detail,
    required this.health,
    required this.onAlerts,
    required this.onUpdateKm,
  });

  final VehicleDetail detail;
  final VehicleHealth health;
  final VoidCallback onAlerts;
  final VoidCallback onUpdateKm;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = detail.vehicle;
    final h = health;
    final pct = h.healthPercent;
    final maint = v.maintenance.fold<double>(0, (s, r) => s + (r.cost ?? 0));
    final fuel = v.fuelLogs.fold<double>(0, (s, f) => s + (f.total ?? 0));
    final isBoat = v.type == VehicleType.barco;
    final roleChip = v.isOwner
        ? switch (v.ownerRole) {
            'regular' => '👤 Usuario habitual',
            'company' => '🏢 Empresa',
            'mechanic' => '🔧 Taller',
            _ => '👑 Propietario',
          }
        : '🔗 Compartido · ${v.accessRole.label}';
    final zoneChip = switch (v.zone) {
      'costa' => '🌊 Costa',
      'montana' => '🏔️ Montaña',
      'mixto' => '🗺️ Mixto',
      'norte' => '🌧️ Norte húmedo',
      _ => '🏙️ Interior',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = ((constraints.maxWidth - DetailTabScroll.maxWidth) / 2).clamp(16.0, double.infinity);
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 16, side, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text(v.type.emoji, style: const TextStyle(fontSize: 34))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                        if (v.subtitle.isNotEmpty || v.fuelType != null)
                          Text(
                            [if (v.subtitle.isNotEmpty) v.subtitle, if (v.fuelType != null) v.fuelType!]
                                .join(' · '),
                            style: TextStyle(color: c.textMid, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (pct != null)
                    Semantics(
                      label: 'Salud $pct por ciento',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$pct%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                color: pct > 70 ? c.ok : (pct > 40 ? c.warning : c.danger),
                              )),
                          Text('salud', style: TextStyle(color: c.textSoft, fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  InfoChip(label: roleChip, tone: v.isOwner ? BadgeTone.neutral : BadgeTone.info),
                  if (!isBoat) InfoChip(label: zoneChip),
                  if (v.usage != null) InfoChip(label: '🛣️ ${v.usage}'),
                  if (v.isOwner && v.sharedCount > 0)
                    InfoChip(label: '👥 ${plural(v.sharedCount, 'persona', 'personas')}', tone: BadgeTone.info),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!isBoat) ...[
                    Expanded(child: StatBox(label: 'Km', value: v.currentKm != null ? Fmt.km(v.currentKm!) : '—')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatBox(
                        label: h.annualKmIsMeasured ? 'Km/año ✓' : 'Km/año',
                        value: Fmt.thousands(h.annualKm),
                        valueColor: h.annualKmIsMeasured ? c.ok : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: StatBox(label: 'Manten.', value: maint > 0 ? Fmt.euros(maint) : '—')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatBox(label: 'Combustible', value: fuel > 0 ? Fmt.euros(fuel) : '—', valueColor: c.fuel),
                  ),
                ],
              ),
              if (h.alerts.isNotEmpty) ...[
                const SizedBox(height: 10),
                _HeaderBanner(
                  tone: h.danger > 0 ? BadgeTone.danger : BadgeTone.warning,
                  text: '⚠️ ${plural(h.alerts.length, 'mantenimiento pendiente', 'mantenimientos pendientes')}',
                  action: '¿Qué hago? →',
                  onTap: onAlerts,
                ),
              ],
              if (!isBoat && h.kmUpdateDue) ...[
                const SizedBox(height: 8),
                _HeaderBanner(
                  tone: BadgeTone.info,
                  text: h.daysSinceKmLog == null
                      ? '📍 Aún no hay lecturas de km'
                      : '📍 ${h.daysSinceKmLog} días sin anotar los km',
                  action: 'Actualizar →',
                  onTap: onUpdateKm,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.tone, required this.text, required this.action, required this.onTap});

  final BadgeTone tone;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = StatusBadge.toneColors(context, tone);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13))),
              Text(action, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const SkeletonPulse(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SkeletonBox(width: 40, height: 40, radius: 10),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 22)),
              ]),
              SizedBox(height: 16),
              SkeletonBox(height: 56, radius: 10),
              SizedBox(height: 16),
              SkeletonBox(height: 36, radius: 8),
              SizedBox(height: 16),
              SkeletonBox(height: 90, radius: 14),
              SizedBox(height: 10),
              SkeletonBox(height: 90, radius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.emoji,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String emoji;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyTabMessage(emoji: emoji, title: title, body: body),
                AppButton(label: actionLabel, onPressed: onAction, expand: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
