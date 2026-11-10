import 'package:flutter/material.dart';
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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  AuthFailure? _error;

  @override
  void dispose() {
    _email.dispose();
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
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      // Solo mostramos errores que el usuario puede resolver. Cualquier otro
      // caso se trata como enviado, para no revelar qué emails existen.
      if (!mounted) return;
      if (e.type == AuthFailureType.rateLimited || e.type == AuthFailureType.network) {
        setState(() => _error = e);
      } else {
        setState(() => _sent = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthLayout(
        showLogo: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExcludeSemantics(
              child: Text('✉️', textAlign: TextAlign.center, style: TextStyle(fontSize: 60)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Revisa tu correo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'Si existe una cuenta con ${_email.text.trim()}, recibirás un enlace '
              'para crear una contraseña nueva. Ábrelo desde este dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textMid, height: 1.6),
            ),
            const SizedBox(height: 28),
            AppButton(label: 'Volver a iniciar sesión', onPressed: () => context.go(Routes.login)),
          ],
        ),
      );
    }

    return AuthLayout(
      showBack: true,
      showLogo: false,
      title: 'Recuperar contraseña',
      subtitle: 'Te enviaremos un enlace para crear una nueva',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Correo electrónico'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: Validators.email,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: 'tu@email.com'),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              MessageBanner(message: _error!.message),
              const SizedBox(height: 12),
            ],
            AppButton(label: 'Enviar enlace', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
