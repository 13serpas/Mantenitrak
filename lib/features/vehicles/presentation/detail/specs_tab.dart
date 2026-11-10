import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../data/specs_repository.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_draft.dart';
import '../../domain/vehicle_specs.dart';
import '../providers/vehicle_detail_provider.dart';
import '../widgets/specs_form.dart';
import 'detail_widgets.dart';

/// Pestaña "Ficha": aceite, filtros, neumáticos y batería. El propietario
/// puede editarla, pedirla a la IA o quitarla.
class SpecsTab extends ConsumerStatefulWidget {
  const SpecsTab({super.key, required this.vehicle, required this.specs});

  final Vehicle vehicle;
  final VehicleSpecs? specs;

  @override
  ConsumerState<SpecsTab> createState() => _SpecsTabState();
}

enum _Busy { none, generating, saving }

class _SpecsTabState extends ConsumerState<SpecsTab> {
  VehicleSpecs? _draft; // != null => editando
  bool _changed = false;
  int _generation = 0;
  _Busy _busy = _Busy.none;
  String? _error;

  VehicleDraft get _vehicleDraft => VehicleDraft.fromVehicle(widget.vehicle);

  List<SpecField> get _fields => VehicleSpecs.fieldsFor(
        type: widget.vehicle.type,
        electric: _vehicleDraft.isElectric,
        diesel: _vehicleDraft.isDiesel,
      );

  void _startEdit(VehicleSpecs base) => setState(() {
        _draft = base;
        _changed = false;
        _generation++;
        _error = null;
      });

  void _cancel() => setState(() {
        _draft = null;
        _error = null;
      });

  Future<void> _generate() async {
    if (widget.specs != null &&
        !await confirmDialog(
          context,
          title: 'Generar de nuevo',
          message: 'La IA propondrá una ficha nueva. Podrás revisarla antes de guardar; '
              'hasta entonces se mantiene la actual.',
          confirmLabel: 'Generar',
        )) {
      return;
    }
    setState(() {
      _busy = _Busy.generating;
      _error = null;
    });
    try {
      final specs = await ref.read(specsRepositoryProvider).generate(_vehicleDraft);
      if (!mounted) return;
      _startEdit(specs);
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final invalid = _fields.any((f) => VehicleSpecs.validateField(f, draft.valueOf(f.key)) != null);
    if (invalid) {
      setState(() => _error = 'Revisa los campos marcados en rojo.');
      return;
    }
    // Si el usuario corrige una ficha de la IA, pasa a ser suya.
    final toSave = _changed ? draft.withSource(SpecsSource.manual) : draft;
    setState(() {
      _busy = _Busy.saving;
      _error = null;
    });
    try {
      await ref.read(vehicleActionsProvider).saveSpecs(widget.vehicle.id, toSave);
      if (!mounted) return;
      setState(() => _draft = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toSave.isEmpty ? 'Ficha técnica eliminada' : 'Ficha técnica guardada')),
      );
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Quitar ficha técnica',
      message: 'Se borrarán todos los datos de la ficha de este vehículo.',
      confirmLabel: 'Quitar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _Busy.saving);
    try {
      await ref.read(vehicleActionsProvider).saveSpecs(widget.vehicle.id, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficha técnica eliminada')));
      }
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = _Busy.none);
    }
  }

  Future<void> _copy(VehicleSpecs specs) async {
    final v = widget.vehicle;
    final lines = [
      '${v.displayName}${v.year > 0 ? ' (${v.year})' : ''}${v.engine != null ? ' · ${v.engine}' : ''}',
      for (final f in _fields)
        if (specs.valueOf(f.key).isNotEmpty) '${f.label}: ${specs.valueOf(f.key)}${f.numeric ? ' L' : ''}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ficha copiada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.vehicle.isOwner;
    final specs = widget.specs;
    final draft = _draft;

    final errorBanner = _error == null ? null : MessageBanner(message: _error!);

    if (_busy == _Busy.generating) {
      return const DetailTabScroll(
        storageKey: 'ficha',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Consultando especificaciones…'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── Editando ─────────────────────────────────────────────
    if (draft != null) {
      return DetailTabScroll(
        storageKey: 'ficha',
        children: [
          SpecsForm(
            specs: draft,
            type: widget.vehicle.type,
            electric: _vehicleDraft.isElectric,
            diesel: _vehicleDraft.isDiesel,
            generation: _generation,
            onChanged: (k, v) => setState(() {
              _draft = _draft!.withValue(k, v);
              _changed = true;
            }),
          ),
          if (errorBanner != null) errorBanner,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.outline,
                  onPressed: _busy == _Busy.none ? _cancel : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(label: 'Guardar ficha', loading: _busy == _Busy.saving, onPressed: _save),
              ),
            ],
          ),
        ],
      );
    }

    // ── Sin ficha ────────────────────────────────────────────
    if (specs == null) {
      if (!isOwner) {
        return const DetailTabScroll(
          storageKey: 'ficha',
          children: [
            EmptyTabMessage(
              emoji: '📄',
              title: 'Sin ficha técnica',
              body: 'El propietario aún no ha añadido la ficha técnica de este vehículo.',
            ),
          ],
        );
      }
      return DetailTabScroll(
        storageKey: 'ficha',
        children: [
          const EmptyTabMessage(
            emoji: '📄',
            title: 'Añade la ficha técnica',
            body: 'Aceite, filtros, neumáticos y batería: lo que necesitas al ir al taller o comprar recambios.',
          ),
          if (errorBanner != null) errorBanner,
          AppButton(label: '🤖  Generar con IA', onPressed: _generate),
          AppButton(
            label: 'Rellenar a mano',
            variant: AppButtonVariant.outline,
            onPressed: () => _startEdit(const VehicleSpecs(source: SpecsSource.manual)),
          ),
        ],
      );
    }

    // ── Ficha guardada ───────────────────────────────────────
    final c = context.colors;
    return DetailTabScroll(
      storageKey: 'ficha',
      children: [
        if (specs.source.isAutomatic)
          const MessageBanner(
            tone: BannerTone.info,
            message: 'Datos orientativos generados por IA. Compruébalos en el manual o con tu taller '
                'antes de comprar recambios.',
          ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final (i, f) in _fields.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                _SpecRow(field: f, value: specs.valueOf(f.key)),
              ],
            ],
          ),
        ),
        if (specs.oilBrands.isNotEmpty)
          Text('Marcas de aceite sugeridas: ${specs.oilBrands.join(', ')}',
              style: TextStyle(color: c.textMid, fontSize: 12.5)),
        if (errorBanner != null) errorBanner,
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => _copy(specs),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
            ),
            if (isOwner) ...[
              TextButton.icon(
                onPressed: _busy == _Busy.none ? () => _startEdit(specs) : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              TextButton.icon(
                onPressed: _busy == _Busy.none ? _generate : null,
                icon: const Text('🤖'),
                label: const Text('Generar de nuevo'),
              ),
              TextButton.icon(
                onPressed: _busy == _Busy.none ? _remove : null,
                style: TextButton.styleFrom(foregroundColor: c.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
            ],
          ],
        ),
        if (!isOwner)
          Text('Solo el propietario puede cambiar la ficha.', style: TextStyle(color: c.textSoft, fontSize: 12)),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.field, required this.value});

  final SpecField field;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = value.isEmpty ? '—' : (field.numeric ? '$value L' : value);
    return Semantics(
      label: '${field.label}: ${value.isEmpty ? 'sin datos' : shown}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 26, child: Text(field.icon, style: const TextStyle(fontSize: 15))),
            Expanded(
              flex: 5,
              child: Text(field.label, style: TextStyle(color: c.textMid, fontSize: 13.5)),
            ),
            Expanded(
              flex: 6,
              child: Text(
                shown,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: value.isEmpty ? c.textSoft : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
