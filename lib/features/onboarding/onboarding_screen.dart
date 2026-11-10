import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';

/// Se muestra solo la primera vez (antes se mostraba en cada arranque sin sesión).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    ('🔩', 'Bienvenido a ManteniTrack',
        'El registro inteligente de mantenimiento para todos tus vehículos.'),
    ('📋', 'Sin conocimientos técnicos',
        'La app te dice qué revisar, cuándo y por qué, en lenguaje claro.'),
    ('⛽', 'Combustible y gastos',
        'Repostajes, seguros, multas y todos los gastos del vehículo en un lugar.'),
    ('🗺️', 'Viajes con checklist',
        'Revisa el vehículo antes de salir y calcula el gasto del viaje.'),
    ('🤖', 'IA que trabaja por ti',
        'Genera la ficha técnica y analiza tus neumáticos con una foto.'),
  ];

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(Routes.withFrom(Routes.login, widget.from));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final (emoji, title, body) = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Text(emoji, style: const TextStyle(fontSize: 72)),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              body,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textMid, fontSize: 15, height: 1.6),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Semantics(
                  label: 'Página ${_page + 1} de ${_slides.length}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? primary : colors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    children: [
                      AppButton(
                        label: _isLast ? 'Empezar' : 'Siguiente',
                        onPressed: _isLast
                            ? _finish
                            : () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                      ),
                      const SizedBox(height: 4),
                      AppButton(
                        label: _isLast ? 'Ya tengo cuenta' : 'Saltar',
                        variant: AppButtonVariant.ghost,
                        onPressed: _finish,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
