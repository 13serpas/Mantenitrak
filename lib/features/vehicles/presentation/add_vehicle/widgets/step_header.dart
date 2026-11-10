import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: context.colors.textMid, fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
