import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/vehicle_draft.dart';
import '../providers/add_vehicle_controller.dart';
import 'steps/data_step.dart';
import 'steps/role_zone_steps.dart';
import 'steps/specs_step.dart';
import 'steps/type_step.dart';
import 'steps/usage_step.dart';

/// Punto 3: asistente para añadir un vehículo.
class AddVehicleScreen extends ConsumerWidget {
  const AddVehicleScreen({super.key});

  Future<void> _handleBack(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(addVehicleControllerProvider.notifier);
    if (controller.back()) return;
    final state = ref.read(addVehicleControllerProvider);
    if (!state.isDirty || await _confirmDiscard(context)) {
      if (context.mounted) context.pop();
    }
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderán los datos que has introducido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir editando')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final state = ref.read(addVehicleControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final title = state.draft.title;
    final id = await ref.read(addVehicleControllerProvider.notifier).save();
    if (id == null || !context.mounted) return;
    // Hasta que exista el detalle (punto 4), volvemos al inicio.
    context.go(Routes.home);
    messenger.showSnackBar(SnackBar(content: Text('✓ $title añadido')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addVehicleControllerProvider);
    final controller = ref.read(addVehicleControllerProvider.notifier);
    final steps = state.steps;
    final c = context.colors;

    return PopScope(
      // El botón "atrás" del sistema retrocede un paso; en el primero, confirma.
      canPop: state.isFirst && !state.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Añadir vehículo'),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (!state.isDirty || await _confirmDiscard(context)) {
                if (context.mounted) context.pop();
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(34),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Semantics(
                label: 'Paso ${state.stepIndex + 1} de ${steps.length}: ${state.step.label}',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text('Paso ${state.stepIndex + 1} de ${steps.length}',
                              style: TextStyle(color: c.textSoft, fontSize: 12)),
                          const Spacer(),
                          Text(state.step.label,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: (state.stepIndex + 1) / steps.length),
                          duration: const Duration(milliseconds: 250),
                          builder: (_, v, __) => LinearProgressIndicator(
                            value: v,
                            minHeight: 5,
                            backgroundColor: c.surfaceAlt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(state.step),
                          child: switch (state.step) {
                            WizardStep.type => const TypeStep(),
                            WizardStep.data => const DataStep(),
                            WizardStep.usage => const UsageStep(),
                            WizardStep.role => const RoleStep(),
                            WizardStep.zone => const ZoneStep(),
                            WizardStep.specs => const SpecsStep(),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _BottomBar(
                state: state,
                onBack: () => _handleBack(context, ref),
                onNext: controller.next,
                onSave: () => _save(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final AddVehicleState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.saveError != null) ...[
                MessageBanner(message: state.saveError!),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (!state.isFirst) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Atrás',
                        variant: AppButtonVariant.outline,
                        onPressed: state.saving ? null : onBack,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: state.isLast
                        ? AppButton(
                            label: 'Añadir vehículo',
                            loading: state.saving,
                            onPressed: state.canContinue ? onSave : null,
                          )
                        : AppButton(
                            label: 'Siguiente',
                            onPressed: state.canContinue ? onNext : null,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
