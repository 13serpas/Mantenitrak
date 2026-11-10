import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'widgets/auth_layout.dart';
import 'widgets/password_field.dart';

/// Se muestra al abrir el enlace del correo de recuperación. El router no
/// deja salir de aquí hasta que se guarda la contraseña o se cierra sesión.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _loading = false;
  AuthFailure? _error;

  @override
  void dispose() {
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
      // Libera al router, que llevará al usuario a la pantalla principal.
      ref.read(authRouterStateProvider).finishRecovery();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Cerrar sesión también saca del modo recuperación (lo hace el router).
  Future<void> _cancel() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Nueva contraseña',
      subtitle: 'Elige una contraseña que no hayas usado antes',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Nueva contraseña'),
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
              AppButton(label: 'Guardar contraseña', loading: _loading, onPressed: _submit),
              const SizedBox(height: 8),
              AppButton(
                label: 'Cancelar',
                variant: AppButtonVariant.ghost,
                onPressed: _loading ? null : _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
