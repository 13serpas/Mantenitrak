import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../maintenance/domain/maintenance_entry.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/providers/vehicle_detail_provider.dart';
import '../domain/fuel_entry.dart';

/// Punto 6: registrar un repostaje (o una recarga en eléctricos).
class AddFuelScreen extends ConsumerWidget {
  const AddFuelScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vehicleDetailProvider(vehicleId));
    Widget simple(Widget body) => Scaffold(appBar: AppBar(title: const Text('Registrar repostaje')), body: body);
    return detail.when(
      loading: () => simple(const Center(child: CircularProgressIndicator())),
      error: (e, _) => simple(Padding(
        padding: const EdgeInsets.all(24),
        child: MessageBanner(message: e is DataFailure ? e.message : 'No se ha podido cargar el vehículo.'),
      )),
      data: (d) => d == null
          ? simple(const Padding(
              padding: EdgeInsets.all(24),
              child: MessageBanner(message: 'Este vehículo ya no está disponible.'),
            ))
          : _FuelForm(vehicle: d.vehicle),
    );
  }
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm> {
  late FuelEntry _entry = FuelEntry.initial(widget.vehicle);
  late final List<String> _options = FuelEntry.optionsFor(widget.vehicle.fuelType);
  late final List<String> _stations = FuelEntry.recentStations(widget.vehicle.fuelLogs);
  final _kmCtrl = TextEditingController();
  final _ctrls = {for (final f in FuelField.values) f: TextEditingController()};
  bool _saving = false;
  String? _error;

  Vehicle get _v => widget.vehicle;
  bool get _usesKm => _v.type != VehicleType.barco;
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _dirty =>
      FuelField.values.any((f) => _entry.valueOf(f).isNotEmpty) || _entry.km.isNotEmpty || _entry.station.isNotEmpty;

  @override
  void dispose() {
    _kmCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(FuelEntry e) => setState(() {
        _entry = e;
        _error = null;
      });

  /// El usuario escribe un importe: los demás campos (el calculado o uno
  /// que se ha vaciado) se actualizan sin mover el cursor del actual.
  void _onAmount(FuelField field, String text) {
    final next = _entry.withField(field, text);
    for (final f in FuelField.values) {
      if (f == field) continue;
      final value = next.valueOf(f);
      if (_ctrls[f]!.text != value) _ctrls[f]!.text = value;
    }
    _set(next);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entry.date,
      firstDate: DateTime(1990),
      lastDate: _today,
      helpText: 'Fecha del repostaje',
    );
    if (picked != null && mounted) _set(_entry.copyWith(date: picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = _entry.validate(_usesKm ? _v.kmLogs : const []);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(vehicleActionsProvider).registerFuel(_v.id, _entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_entry.isElectric ? '✓ Recarga registrada' : '✓ Repostaje registrado')),
      );
      context.pop();
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = _entry;
    final kmError = _usesKm ? MaintenanceEntry.validateKm(e.km, e.date, _v.kmLogs) : null;
    final preview = _usesKm ? e.previewConsumption(_v.fuelLogs) : null;
    final derived = e.derived;
    final electric = e.isElectric;
    final title = electric ? 'Registrar recarga' : 'Registrar repostaje';
    final lastKm = _v.currentKm;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: '¿Salir sin guardar?',
          message: 'Se perderán los datos de ${electric ? 'esta recarga' : 'este repostaje'}.',
          confirmLabel: 'Salir',
          cancelLabel: 'Seguir',
          destructive: true,
        );
        if (ok && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 8)],
                if (e.totalValue != null && e.quantityValue != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${Fmt.decimal(e.quantityValue!, 2)} ${e.unit} · ${Fmt.money(e.totalValue!)}'
                      '${e.fullTank ? ' · lleno' : ' · parcial'}',
                      style: TextStyle(color: c.textMid, fontSize: 12.5),
                    ),
                  ),
                AppButton(label: _saving ? 'Guardando…' : 'Guardar', onPressed: _saving ? null : _save),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('${_v.type.emoji}  ${_v.displayName}', style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            // ── Combustible ──────────────────────────────────
            if (_options.length > 1) ...[
              const FieldLabel('¿Qué has echado?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in _options)
                    ChoiceChip(
                      label: Text(o == 'Electricidad' ? '🔌 Electricidad' : o),
                      selected: e.fuelType == o,
                      onSelected: _saving ? null : (_) => _set(_entry.copyWith(fuelType: o)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // ── Fecha y km ───────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Fecha'),
                      Semantics(
                        button: true,
                        label: 'Fecha: ${Fmt.date(e.date)}. Pulsa para cambiarla.',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: _saving ? null : _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                            child: Text(e.date == _today ? 'Hoy' : Fmt.date(e.date)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_usesKm) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Kilómetros'),
                        TextField(
                          controller: _kmCtrl,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                          onChanged: (v) => _set(_entry.copyWith(km: v)),
                          decoration: InputDecoration(
                            suffixText: 'km',
                            hintText: lastKm != null ? 'Último: ${Fmt.thousands(lastKm)}' : null,
                            errorText: kmError,
                            errorMaxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_usesKm && kmError == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  e.km.isEmpty
                      ? 'Opcional, pero sin km no se puede calcular el consumo.'
                      : 'Se guardará también como lectura de kilometraje.',
                  style: TextStyle(color: c.textSoft, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            // ── Importes ─────────────────────────────────────
            Semantics(
              header: true,
              child: const Text('Importes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(height: 4),
            Text(
              'Escribe dos de los tres (los que vengan en el ticket) y calculamos el otro.',
              style: TextStyle(color: c.textMid, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            _AmountField(
              controller: _ctrls[FuelField.total]!,
              label: 'Total pagado',
              suffix: '€',
              computed: derived == FuelField.total,
              enabled: !_saving,
              maxLength: 8,
              validator: FuelEntry.validateTotal,
              onChanged: (v) => _onAmount(FuelField.total, v),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AmountField(
                    controller: _ctrls[FuelField.quantity]!,
                    label: electric ? 'Energía' : 'Litros',
                    suffix: e.unit,
                    computed: derived == FuelField.quantity,
                    enabled: !_saving,
                    maxLength: 7,
                    validator: (v) => FuelEntry.validateQuantity(v, unit: e.unit),
                    onChanged: (v) => _onAmount(FuelField.quantity, v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AmountField(
                    controller: _ctrls[FuelField.price]!,
                    label: 'Precio',
                    suffix: e.priceUnit,
                    computed: derived == FuelField.price,
                    enabled: !_saving,
                    maxLength: 6,
                    validator: FuelEntry.validatePrice,
                    onChanged: (v) => _onAmount(FuelField.price, v),
                  ),
                ),
              ],
            ),
            if (e.amountsMismatch) ...[
              const SizedBox(height: 10),
              MessageBanner(
                message: '${Fmt.decimal(e.quantityValue!, 2)} ${e.unit} × ${Fmt.decimal(e.priceValue!, 3)} '
                    '= ${Fmt.money(e.quantityValue! * e.priceValue!)}, no ${Fmt.money(e.totalValue!)}. Revisa algún importe.',
              ),
            ] else if (e.priceWarning != null) ...[
              const SizedBox(height: 10),
              MessageBanner(tone: BannerTone.info, message: e.priceWarning!),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: e.fullTank,
              onChanged: _saving ? null : (v) => _set(_entry.copyWith(fullTank: v)),
              title: Text(electric ? 'Carga completa' : 'He llenado el depósito'),
              subtitle: Text(
                electric
                    ? 'Hasta el 100 % (o tu límite habitual). Así podemos calcular el consumo real.'
                    : 'El consumo se calcula de lleno a lleno, sumando también los repostajes parciales.',
                style: TextStyle(color: c.textSoft, fontSize: 12),
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 4),
              MessageBanner(
                tone: BannerTone.info,
                message: 'Este ${electric ? 'tramo' : 'depósito'}: ${Fmt.decimal(preview.value)} ${preview.unit} km'
                    '${preview.average != null ? ' (tu media hasta ahora: ${Fmt.decimal(preview.average!)})' : ''}.',
              ),
            ],
            const SizedBox(height: 16),
            // ── Gasolinera ───────────────────────────────────
            FieldLabel(electric ? 'Dónde (opcional)' : 'Gasolinera (opcional)'),
            Autocomplete<String>(
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                return q.isEmpty ? _stations.take(5) : _stations.where((s) => s.toLowerCase().contains(q)).take(5);
              },
              onSelected: (s) => _set(_entry.copyWith(station: s)),
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                onChanged: (v) => _set(_entry.copyWith(station: v)),
                decoration: InputDecoration(
                  hintText: electric ? 'Casa, trabajo, cargador…' : 'Repsol de la avenida…',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de importe. El calculado se ve con fondo de color y la etiqueta
/// "calculado"; se puede sobrescribir y entonces se calcula otro.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.computed,
    required this.enabled,
    required this.maxLength,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool computed;
  final bool enabled;
  final int maxLength;
  final String? Function(String) validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: onChanged,
      style: computed ? TextStyle(color: c.fuel, fontWeight: FontWeight.w700) : null,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: computed ? true : null,
        fillColor: computed ? c.fuelLight : null,
        helperText: computed ? 'Calculado' : null,
        errorText: controller.text.isEmpty ? null : validator(controller.text),
      ),
    );
  }
}
