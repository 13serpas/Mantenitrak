import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'widgets/auth_layout.dart';
import 'widgets/confirm_email_view.dart';
import 'widgets/google_button.dart';
import 'widgets/password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  AuthFailure? _error;
  String? _confirmationSentTo;

  bool get _busy => _loading || _googleLoading;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      TextInput.finishAutofillContext();
      if (result == SignUpResult.confirmationSent && mounted) {
        setState(() => _confirmationSentTo = _email.text.trim());
      }
      // Si la confirmación de email está desactivada (SignUpResult.signedIn),
      // el router redirige solo.
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
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmationSentTo != null) {
      return ConfirmEmailView(email: _confirmationSentTo!);
    }

    return AuthLayout(
      showBack: true,
      showLogo: false,
      title: 'Crear cuenta',
      subtitle: 'Lleva el mantenimiento de tus vehículos al día',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GoogleButton(loading: _googleLoading, onPressed: _busy ? null : _google),
              const OrDivider(),
              const FieldLabel('Nombre'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: Validators.name,
                decoration: const InputDecoration(hintText: 'Tu nombre'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Correo electrónico'),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                validator: Validators.email,
                decoration: const InputDecoration(hintText: 'tu@email.com'),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Contraseña'),
              PasswordField(
                controller: _password,
                hintText: 'Mínimo ${Validators.minPasswordLength} caracteres',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 16),
              const FieldLabel('Repetir contraseña'),
              PasswordField(
                controller: _password2,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.confirmPassword(() => _password.text),
                onSubmitted: _submit,
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                MessageBanner(message: _error!.message),
                const SizedBox(height: 12),
              ],
              AppButton(
                label: 'Crear cuenta',
                loading: _loading,
                onPressed: _busy ? null : _submit,
              ),
              const SizedBox(height: 14),
              Text(
                'Al registrarte aceptas los Términos de uso y la Política de privacidad de ManteniTrack.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSoft, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
