import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'widgets/auth_layout.dart';
import 'widgets/google_button.dart';
import 'widgets/password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Ruta a la que volver tras iniciar sesión (la gestiona el router).
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  AuthFailure? _error;
  String? _info;

  bool get _busy => _loading || _googleLoading;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
      TextInput.finishAutofillContext();
      // No navegamos: el router detecta la sesión y redirige.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _googleLoading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(_email.text);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'Te hemos reenviado el correo de confirmación a ${_email.text.trim()}.';
        });
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AuthLayout(
      title: 'ManteniTrack',
      subtitle: 'Inicia sesión para continuar',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Correo electrónico'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                autocorrect: false,
                validator: Validators.email,
                decoration: const InputDecoration(hintText: 'tu@email.com'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Contraseña'),
              PasswordField(
                controller: _password,
                validator: Validators.password,
                onSubmitted: _submit,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : () => context.push(Routes.forgotPassword),
                  child: const Text('¿Olvidaste la contraseña?'),
                ),
              ),
              if (_error != null) ...[
                MessageBanner(
                  message: _error!.message,
                  actionLabel: _error!.type == AuthFailureType.emailNotConfirmed
                      ? 'Reenviar correo'
                      : null,
                  onAction: _resendConfirmation,
                ),
                const SizedBox(height: 12),
              ],
              if (_info != null) ...[
                MessageBanner(message: _info!, tone: BannerTone.success),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: 'Entrar',
                loading: _loading,
                onPressed: _busy ? null : _submit,
              ),
              const OrDivider(),
              GoogleButton(loading: _googleLoading, onPressed: _busy ? null : _google),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('¿No tienes cuenta? ', style: TextStyle(color: context.colors.textMid)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => context.push(Routes.withFrom(Routes.register, widget.from)),
                    child: Text(
                      'Regístrate',
                      style: TextStyle(color: primary, fontWeight: FontWeight.w700),
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
