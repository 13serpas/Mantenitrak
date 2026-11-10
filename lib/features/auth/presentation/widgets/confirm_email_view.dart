import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_failure.dart';
import 'auth_layout.dart';

/// "Revisa tu correo", con reenvío limitado a uno por minuto.
class ConfirmEmailView extends ConsumerStatefulWidget {
  const ConfirmEmailView({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ConfirmEmailView> createState() => _ConfirmEmailViewState();
}

class _ConfirmEmailViewState extends ConsumerState<ConfirmEmailView> {
  static const _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _timer;
  bool _sending = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = _cooldown);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
      _feedback = 'Correo reenviado.';
      _feedbackIsError = false;
      _startCooldown();
    } on AuthFailure catch (e) {
      _feedback = e.message;
      _feedbackIsError = true;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft <= 0 && !_sending;
    return AuthLayout(
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Text('📧', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Confirma tu email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Hemos enviado un enlace a ${widget.email}.\n'
            'Ábrelo desde este dispositivo para activar tu cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMid, height: 1.6),
          ),
          const SizedBox(height: 28),
          if (_feedback != null) ...[
            MessageBanner(
              message: _feedback!,
              tone: _feedbackIsError ? BannerTone.error : BannerTone.success,
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: 'Ir a iniciar sesión',
            onPressed: () => context.go(Routes.login),
          ),
          const SizedBox(height: 8),
          AppButton(
            variant: AppButtonVariant.ghost,
            loading: _sending,
            label: canResend || _sending
                ? 'Reenviar correo'
                : 'Reenviar correo ($_secondsLeft s)',
            onPressed: canResend ? _resend : null,
          ),
        ],
      ),
    );
  }
}
