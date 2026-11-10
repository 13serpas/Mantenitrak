import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../auth/data/auth_repository.dart';
import '../data/vehicle_repository.dart';
import '../domain/vehicle.dart';
import 'providers/vehicles_provider.dart';
import 'widgets/home_notices.dart';
import 'widgets/km_update_sheet.dart';
import 'widgets/vehicle_health_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(homeOverviewProvider);
    final brightness = Theme.of(context).brightness;
    final hasWorkshop = overview.valueOrNull?.vehicles.any((v) => v.isWorkshop) ?? false;
    final workshop = hasWorkshop && ref.watch(workshopModeProvider);

    void openVehicle(Vehicle v) => context.push(Routes.vehicleDetail(v.id));
    // Desde un aviso se abre directamente la pestaña "¿Qué hacer?".
    void openAlert(Vehicle v) => context.push(Routes.vehicleDetail(v.id, tab: 'que-hacer'));

    Future<void> updateKm(Vehicle v) async {
      final saved = await KmUpdateSheet.show(context, v);
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kilometraje de ${v.displayName} actualizado')),
        );
      }
    }

    Future<void> refresh() async {
      try {
        await ref.read(vehiclesProvider.notifier).refresh();
      } on DataFailure {
        // El error ya se muestra en pantalla a través del provider.
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 28),
            SizedBox(width: 10),
            Text('ManteniTrack'),
          ],
        ),
        actions: [
          if (hasWorkshop)
            IconButton(
              tooltip: workshop ? 'Salir del modo taller' : 'Modo taller',
              isSelected: workshop,
              icon: const Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build, color: Theme.of(context).colorScheme.primary),
              onPressed: () => ref.read(workshopModeProvider.notifier).state = !workshop,
            ),
          IconButton(
            tooltip: brightness == Brightness.dark ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'join') context.push(Routes.joinVehicle());
              if (value == 'logout') ref.read(authRepositoryProvider).signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'join', child: Text('Unirme a un vehículo')),
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addVehicle),
        icon: const Icon(Icons.add),
        label: const Text('Añadir vehículo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: overview.when(
          loading: () => const _HomeList(
            children: [VehicleHealthCardSkeleton(), VehicleHealthCardSkeleton()],
          ),
          error: (e, _) => _MessageView(
            emoji: '😕',
            title: 'No se han podido cargar tus vehículos',
            body: e is DataFailure ? e.message : 'Ha ocurrido un error inesperado.',
            actionLabel: 'Reintentar',
            onAction: refresh,
          ),
          data: (o) {
            if (o.vehicles.isEmpty) {
              return _MessageView(
                emoji: '🔧',
                title: 'Aún no tienes vehículos',
                body: 'Añade tu primer vehículo y te diremos qué revisar y cuándo.',
                actionLabel: 'Añadir mi primer vehículo',
                onAction: () => context.push(Routes.addVehicle),
                secondaryLabel: 'Tengo un código para unirme a uno',
                onSecondary: () => context.push(Routes.joinVehicle()),
              );
            }
            bool shown(Vehicle v) => !workshop || v.isWorkshop;
            final vehicles = o.vehicles.where(shown).toList();
            final alerts = o.alerts.where((a) => shown(a.vehicle)).toList();
            final kmDue = o.kmUpdateDue.where(shown).toList();
            return _HomeList(
              children: [
                if (workshop)
                  _WorkshopBanner(vehicles: vehicles.length, interventions: alerts.length)
                else
                  const _Greeting(),
                if (alerts.isNotEmpty) AlertsCard(alerts: alerts, onOpenVehicle: openAlert),
                if (kmDue.isNotEmpty) KmReminderCard(vehicles: kmDue, onUpdate: updateKm),
                _SectionHeader(count: vehicles.length, title: workshop ? 'Vehículos del taller' : 'Mis vehículos'),
                for (final v in vehicles)
                  VehicleHealthCard(
                    vehicle: v,
                    health: o.healthOf(v),
                    onTap: () => openVehicle(v),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lista centrada con ancho máximo (cómoda en tablet y web) y siempre
/// desplazable para que funcione "tirar para refrescar".
class _HomeList extends StatelessWidget {
  const _HomeList({required this.children});

  final List<Widget> children;

  static const _maxWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(16.0, (constraints.maxWidth - _maxWidth) / 2);
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, 16, side, 100),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(currentUserProvider)?.userMetadata ?? const <String, dynamic>{};
    final fullName = (meta['full_name'] as String?) ?? (meta['name'] as String?);
    final firstName = fullName?.trim().split(' ').first;
    return Text(
      firstName == null || firstName.isEmpty ? 'Hola 👋' : 'Hola, $firstName 👋',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count, required this.title});

  final int count;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ),
          Text(
            count == 1 ? '1 vehículo' : '$count vehículos',
            style: TextStyle(color: context.colors.textSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío o de error, desplazable para poder refrescar.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.emoji,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String emoji;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 52))),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.textMid, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    AppButton(label: actionLabel, onPressed: onAction, expand: false),
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: 8),
                      TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecera del modo taller (diseño del prototipo).
class _WorkshopBanner extends StatelessWidget {
  const _WorkshopBanner({required this.vehicles, required this.interventions});

  final int vehicles;
  final int interventions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF312E81)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MODO TALLER',
            style: TextStyle(
              color: Color(0xFF93C5FD),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vehicles == 1 ? '1 vehículo asignado' : '$vehicles vehículos asignados',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          ),
          Text(
            interventions == 1 ? '1 intervención pendiente' : '$interventions intervenciones pendientes',
            style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
