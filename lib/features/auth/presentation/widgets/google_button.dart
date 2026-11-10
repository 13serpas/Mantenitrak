import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_button.dart';

class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Continuar con Google',
      variant: AppButtonVariant.outline,
      loading: loading,
      onPressed: onPressed,
      // "G" dibujada con texto para no añadir assets de marca.
      icon: const Text(
        'G',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('o')),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}
