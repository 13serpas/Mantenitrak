import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/field_label.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../../shared/widgets/selection.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_catalog.dart';
import '../../domain/vehicle_draft.dart';
import '../add_vehicle/steps/role_zone_steps.dart';
import '../add_vehicle/widgets/catalog_field.dart';
import '../providers/vehicle_detail_provider.dart';

/// Editar los datos de un vehículo (solo el propietario).
/// Los km no se editan aquí: se anotan con "Actualizar kilometraje" para
/// que quede la lectura en el historial.
class EditVehicleScreen extends ConsumerWidget {
  const EditVehicleScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vehicleDetailProvider(vehicleId));
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Editar vehículo')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Editar vehículo')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: MessageBanner(message: e is DataFailure ? e.message : 'No se ha podido cargar el vehículo.'),
        ),
      ),
      data: (d) {
        if (d == null || !d.vehicle.isOwner) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar vehículo')),
            body: const Padding(
              padding: EdgeInsets.all(24),
              child: MessageBanner(message: 'Solo el propietario puede editar este vehículo.'),
            ),
          );
        }
        return _EditForm(vehicle: d.vehicle);
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final VehicleDraft _original = VehicleDraft.fromVehicle(widget.vehicle);
  late VehicleDraft _draft = _original;
  bool _saving = false;
  String? _error;

  bool get _dirty => _draft.toUpdateJson().toString() != _original.toUpdateJson().toString();

  void _update(VehicleDraft d) => setState(() => _draft = d);

  /// Cambiar de tipo conserva marca y modelo (puede ser solo una
  /// corrección, p. ej. coche → 4x4) y ajusta lo que deja de aplicar.
  void _setType(VehicleType t) {
    final boat = t == VehicleType.barco;
    final fuels = boat ? VehicleDraft.boatFuelTypes : VehicleDraft.fuelTypes;
    _update(VehicleDraft(
      type: t,
      brand: _draft.brand,
      model: _draft.model,
      year: _draft.year,
      engine: _draft.engine,
      plate: _draft.plate,
      currentKm: _draft.currentKm,
      annualKm: boat ? '' : _draft.annualKm,
      fuelType: fuels.contains(_draft.fuelType) ? _draft.fuelType : '',
      usage: boat ? '' : _draft.usage,
      role: _draft.role,
      zone: boat ? 'interior' : _draft.zone,
    ));
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || !_draft.isEditValid()) {
      setState(() => _error = 'Revisa los campos marcados.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(vehicleActionsProvider).update(widget.vehicle.id, _draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados')));
      context.pop();
    } on DataFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() => confirmDialog(
        context,
        title: '¿Descartar los cambios?',
        message: 'Los cambios que has hecho no se guardarán.',
        confirmLabel: 'Descartar',
        cancelLabel: 'Seguir editando',
        destructive: true,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = _draft;
    final type = d.type;
    final isBoat = type == VehicleType.barco;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar vehículo')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 8)],
                AppButton(
                  label: 'Guardar cambios',
                  loading: _saving,
                  onPressed: _dirty ? _save : null,
                ),
              ],
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const FieldLabel('Tipo'),
              DropdownButtonFormField<VehicleType>(
                value: type,
                items: [
                  for (final t in VehicleType.values)
                    DropdownMenuItem(value: t, child: Text('${t.emoji}  ${t.label}')),
                ],
                onChanged: (t) {
                  if (t != null) _setType(t);
                },
              ),
              const SizedBox(height: 16),
              CatalogField(
                label: 'Marca',
                hint: 'ej. Seat',
                initialValue: d.brand,
                options: VehicleCatalog.brands(type),
                validator: (v) => VehicleDraft.validateRequired(v ?? '', 'la marca'),
                onChanged: (v) => _update(_draft.withBrand(v)),
              ),
              const SizedBox(height: 16),
              CatalogField(
                key: ValueKey('model-${VehicleCatalog.normalize(d.brand)}'),
                label: 'Modelo',
                hint: 'ej. Ibiza',
                initialValue: d.model,
                options: VehicleCatalog.models(type, d.brand),
                validator: (v) => VehicleDraft.validateRequired(v ?? '', 'el modelo'),
                onChanged: (v) => _update(_draft.withModel(v)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Año'),
                        TextFormField(
                          initialValue: d.year,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => VehicleDraft.validateYear(v ?? ''),
                          onChanged: (v) => _update(_draft.copyWith(year: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldLabel(isBoat ? 'Matrícula / folio' : 'Matrícula'),
                        TextFormField(
                          initialValue: d.plate,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [LengthLimitingTextInputFormatter(15)],
                          onChanged: (v) => _update(_draft.copyWith(plate: v)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CatalogField(
                key: ValueKey('engine-${VehicleCatalog.normalize(d.brand)}-${VehicleCatalog.normalize(d.model)}'),
                label: 'Motorización',
                hint: isBoat ? 'ej. Mercury 150 CV' : 'ej. 1.0 TSI 110 CV',
                initialValue: d.engine,
                options: VehicleCatalog.engines(d.brand, d.model, type: type),
                textCapitalization: TextCapitalization.none,
                onChanged: (v) => _update(_draft.copyWith(engine: v)),
              ),
              const SizedBox(height: 20),
              const FieldLabel('Combustible'),
              ChoicePills(
                options: isBoat ? VehicleDraft.boatFuelTypes : VehicleDraft.fuelTypes,
                selected: d.fuelType,
                onSelected: (v) => _update(_draft.copyWith(fuelType: v)),
              ),
              if (!isBoat) ...[
                const SizedBox(height: 20),
                const FieldLabel('Uso principal'),
                ChoicePills(
                  options: VehicleDraft.usages,
                  selected: d.usage,
                  onSelected: (v) => _update(_draft.copyWith(usage: v)),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Km al año (opcional)'),
                TextFormField(
                  initialValue: d.annualKm,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => VehicleDraft.validateAnnualKm(v ?? ''),
                  onChanged: (v) => _update(_draft.copyWith(annualKm: v)),
                  decoration: const InputDecoration(
                    suffixText: 'km/año',
                    helperText: 'Solo se usa hasta que haya lecturas de km de más de un mes.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Zona por la que circula'),
                ChoicePills(
                  options: [for (final z in ZoneStep.zones) '${z.$2} ${z.$3}'],
                  selected: [for (final z in ZoneStep.zones) if (z.$1 == d.zone) '${z.$2} ${z.$3}'].firstOrNull ?? '',
                  allowDeselect: false,
                  onSelected: (label) {
                    final z = ZoneStep.zones.firstWhere((z) => '${z.$2} ${z.$3}' == label);
                    _update(_draft.copyWith(zone: z.$1));
                  },
                ),
              ],
              const SizedBox(height: 20),
              const FieldLabel('Tu relación con el vehículo'),
              ChoicePills(
                options: [for (final r in RoleStep.roles) '${r.$2} ${r.$3}'],
                selected: [for (final r in RoleStep.roles) if (r.$1 == d.role) '${r.$2} ${r.$3}'].firstOrNull ?? '',
                allowDeselect: false,
                onSelected: (label) {
                  final r = RoleStep.roles.firstWhere((r) => '${r.$2} ${r.$3}' == label);
                  _update(_draft.copyWith(role: r.$1));
                },
              ),
              if (!isBoat) ...[
                const SizedBox(height: 20),
                Text(
                  'Los km actuales se cambian desde «Actualizar kilometraje» en el detalle, '
                  'para que cada lectura quede guardada en el historial.',
                  style: TextStyle(color: c.textSoft, fontSize: 12.5, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
