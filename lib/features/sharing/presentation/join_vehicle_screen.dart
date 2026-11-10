import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/supabase/data_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../vehicles/domain/vehicle.dart';
import '../domain/share_code.dart';
import 'qr_scan_screen.dart';
import 'share_providers.dart';

/// Punto 7: unirse a un vehículo con un código o escaneando el QR.
/// Desde el QR (mantenitrak://app/join/CODIGO) llega con el código puesto.
class JoinVehicleScreen extends ConsumerStatefulWidget {
  const JoinVehicleScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinVehicleScreen> createState() => _JoinVehicleScreenState();
}

class _JoinVehicleScreenState extends ConsumerState<JoinVehicleScreen> {
  late final _codeCtrl = TextEditingController(text: ShareCode.fromScan(widget.initialCode) ?? '');
  AccessRole _role = AccessRole.regular;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  static const _roles = [
    (AccessRole.regular, '👤', 'Lo uso a menudo', 'Familia, pareja, compañero de piso…'),
    (AccessRole.company, '🏢', 'Es de empresa', 'Vehículo de flota o de trabajo.'),
    (AccessRole.mechanic, '🔧', 'Soy su taller', 'Lo verás también en el modo taller.'),
  ];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(), fullscreenDialog: true),
    );
    if (code == null || !mounted) return;
    setState(() {
      _codeCtrl.text = code;
      _error = null;
    });
  }

  Future<void> _join() async {
    setState(() => _tried = true);
    if (ShareCode.validate(_codeCtrl.text) != null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(shareActionsProvider).join(_codeCtrl.text, _role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.alreadyMember ? 'Ya tenías acceso al ${r.name}' : '✓ Ya puedes ver el ${r.name}'),
      ));
      context.go(Routes.vehicleDetail(r.vehicleId));
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final codeError = _tried || _codeCtrl.text.length >= ShareCode.length ? ShareCode.validate(_codeCtrl.text) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Unirme a un vehículo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Pide al propietario que abra el vehículo en ManteniTrack y pulse «Compartir». '
            'Escanea su QR o escribe el código de 6 caracteres.',
            style: TextStyle(color: c.textMid, height: 1.45),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Escanear QR',
            icon: const Icon(Icons.qr_code_scanner, size: 20),
            variant: AppButtonVariant.outline,
            onPressed: _busy ? null : _scan,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Código'),
          TextField(
            controller: _codeCtrl,
            enabled: !_busy,
            autofocus: widget.initialCode == null,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword, // sin autocorrector ni sugerencias
            inputFormatters: [_CodeFormatter()],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _join(),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 6),
            decoration: InputDecoration(hintText: 'ABC234', errorText: codeError),
          ),
          const SizedBox(height: 20),
          const FieldLabel('¿Cómo usas este vehículo?'),
          for (final (role, emoji, title, hint) in _roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoleOption(
                emoji: emoji,
                title: title,
                hint: hint,
                selected: _role == role,
                onTap: _busy ? null : () => setState(() => _role = role),
              ),
            ),
          Text(
            'El propietario puede cambiarlo después.',
            style: TextStyle(color: c.textSoft, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 12)],
          AppButton(label: 'Unirme', loading: _busy, onPressed: _busy ? null : _join),
        ],
      ),
    );
  }
}

/// Mayúsculas, sin espacios y como mucho 6 caracteres.
class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.length > ShareCode.length) t = t.substring(0, ShareCode.length);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.emoji,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? primary : c.border, width: selected ? 2 : 1),
            color: selected ? primary.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(hint, style: TextStyle(color: c.textSoft, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? primary : c.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}
