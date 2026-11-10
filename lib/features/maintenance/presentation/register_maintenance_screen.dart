import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase/data_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../vehicles/domain/vehicle.dart';
import '../../vehicles/presentation/providers/vehicle_detail_provider.dart';
import '../domain/maintenance_calculator.dart';
import '../domain/maintenance_catalog.dart';
import '../domain/maintenance_entry.dart';
import 'status_tone.dart';

/// Punto 5: registrar uno o varios mantenimientos de una vez.
class RegisterMaintenanceScreen extends ConsumerWidget {
  const RegisterMaintenanceScreen({super.key, required this.vehicleId, this.preselected = const []});

  final String vehicleId;

  /// Trabajos ya marcados al abrir (desde "¿Qué hacer?").
  final List<String> preselected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vehicleDetailProvider(vehicleId));
    Widget simple(Widget body) => Scaffold(appBar: AppBar(title: const Text('Registrar mantenimiento')), body: body);
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
          : _EntryForm(vehicle: d.vehicle, preselected: preselected),
    );
  }
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({required this.vehicle, required this.preselected});

  final Vehicle vehicle;
  final List<String> preselected;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  late final List<MaintenanceItem> _plan = MaintenanceCatalog.planFor(widget.vehicle);
  late final VehicleHealth _health = MaintenanceCalculator.healthOf(widget.vehicle);
  late final Map<String, ItemState> _states = {for (final s in _health.states) s.item.id: s};
  late MaintenanceEntry _entry = MaintenanceEntry.initial(
    plan: _plan,
    preselected: widget.preselected,
    currentKm: widget.vehicle.currentKm,
  );
  late final _kmCtrl = TextEditingController(text: _entry.km);

  /// Mientras el usuario no toque los km, se ajustan solos a la fecha.
  bool _kmTouched = false;
  bool _saving = false;
  (int, int)? _progress;
  String? _error;

  Vehicle get _v => widget.vehicle;
  bool get _usesKm => _v.type != VehicleType.barco;
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    super.dispose();
  }

  void _set(MaintenanceEntry e) => setState(() {
        _entry = e;
        _error = null;
      });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entry.date,
      firstDate: DateTime(1990),
      lastDate: _today,
      helpText: 'Fecha del mantenimiento',
    );
    if (picked == null || !mounted) return;
    var e = _entry.copyWith(date: picked);
    // Un trabajo antiguo no se hizo con los km de hoy.
    if (!_kmTouched && _usesKm) {
      final km = picked == _today ? (_v.currentKm?.toString() ?? '') : '';
      _kmCtrl.text = km;
      e = e.copyWith(km: km);
    }
    _set(e);
  }

  Future<void> _addPhoto(EntryLine line) async {
    if (line.photos.length >= MaintenanceEntry.maxPhotosPerLine) return;
    ImageSource? source = ImageSource.gallery;
    if (!kIsWeb) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Hacer foto'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    try {
      // Reducida y comprimida: una factura se lee bien a 1600 px.
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 75);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _snack('La foto es demasiado grande (máximo 5 MB).');
        return;
      }
      final ext = EntryPhoto.extensionOf(file.name) ?? ((file.mimeType ?? '').contains('png') ? 'png' : 'jpg');
      final photo = EntryPhoto(localId: '${DateTime.now().microsecondsSinceEpoch}', bytes: bytes, extension: ext);
      _set(_entry.updateLine(line.key, (l) => l.copyWith(photos: [...l.photos, photo])));
    } on PlatformException catch (e) {
      _snack(e.code.contains('denied') || e.code.contains('access')
          ? 'Sin permiso para usar la cámara o las fotos. Actívalo en los ajustes del móvil.'
          : 'No se ha podido añadir la foto.');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = _entry.validate(_v.kmLogs);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progress = null;
    });
    try {
      final n = await ref.read(vehicleActionsProvider).registerMaintenance(
            _v.id,
            _entry,
            type: _v.type,
            onProgress: (done, total) {
              if (mounted) setState(() => _progress = (done, total));
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ ${plural(n, 'mantenimiento registrado', 'mantenimientos registrados')}')),
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
    final byCategory = <String, List<MaintenanceItem>>{};
    for (final i in _plan) {
      byCategory.putIfAbsent(i.category, () => []).add(i);
    }
    final pending = [for (final s in _health.alerts) s.item];
    final kmError = _usesKm ? MaintenanceEntry.validateKm(e.km, e.date, _v.kmLogs) : null;
    final customLines = [for (final l in e.lines) if (l.isCustom) l];
    final n = e.lines.length;
    final total = e.total;
    final byTotal = e.costMode == CostMode.total;
    // Reparto estimado que se verá en cada trabajo en modo "total".
    final estimates = byTotal ? e.costsFor(_v.type) : const <String, double?>{};

    final saveLabel = !_saving
        ? (n == 0 ? 'Marca qué se ha hecho' : 'Guardar ${plural(n, 'trabajo', 'trabajos')}')
        : (_progress != null && _progress!.$1 < _progress!.$2)
            ? 'Subiendo fotos ${_progress!.$1 + 1} de ${_progress!.$2}…'
            : 'Guardando…';

    return PopScope(
      canPop: e.lines.isEmpty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: '¿Salir sin guardar?',
          message: 'Se perderán los trabajos que has marcado.',
          confirmLabel: 'Salir',
          cancelLabel: 'Seguir',
          destructive: true,
        );
        if (ok && mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Registrar mantenimiento')),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 8)],
                if (n > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      [
                        plural(n, 'trabajo', 'trabajos'),
                        if (total > 0) '${e.costsAreEstimated ? 'total ' : ''}${Fmt.money(total)}',
                        if (e.photoCount > 0) plural(e.photoCount, 'foto', 'fotos'),
                      ].join(' · '),
                      style: TextStyle(color: c.textMid, fontSize: 12.5),
                    ),
                  ),
                AppButton(
                  label: saveLabel,
                  onPressed: n == 0 || _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          key: const PageStorageKey('registrar-mantenimiento'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('${_v.type.emoji}  ${_v.displayName}',
                style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            // ── Fecha y km ────────────────────────────────────
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
                        const FieldLabel('Km (opcional)'),
                        TextField(
                          controller: _kmCtrl,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                          onChanged: (v) {
                            _kmTouched = true;
                            _set(_entry.copyWith(km: v));
                          },
                          decoration: InputDecoration(
                            suffixText: 'km',
                            hintText: e.date == _today ? null : '¿Cuántos tenía?',
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
            if (_usesKm && e.km.isNotEmpty && kmError == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Se guardará también como lectura de kilometraje.',
                  style: TextStyle(color: c.textSoft, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            // ── Qué se ha hecho ───────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: const Text('¿Qué se ha hecho?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                if (pending.isNotEmpty)
                  TextButton(
                    onPressed: _saving ? null : () => _set(_entry.selectOnly(pending)),
                    style: TextButton.styleFrom(foregroundColor: c.danger),
                    child: Text('⚠️ Pendientes (${pending.length})'),
                  ),
                if (n > 0)
                  TextButton(
                    onPressed: _saving ? null : () => _set(_entry.copyWith(lines: const [])),
                    child: const Text('Quitar todo'),
                  ),
              ],
            ),
            Text(
              'Marca lo que te han hecho. Puedes añadir fotos de cada trabajo (factura, pieza cambiada…).',
              style: TextStyle(color: c.textMid, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CostMode>(
              segments: const [
                ButtonSegment(value: CostMode.perItem, label: Text('Coste por trabajo')),
                ButtonSegment(value: CostMode.total, label: Text('Solo sé el total')),
              ],
              selected: {e.costMode},
              showSelectedIcon: false,
              onSelectionChanged: _saving ? null : (s) => _set(_entry.copyWith(costMode: s.first)),
            ),
            if (byTotal) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('total-cost'),
                initialValue: e.totalCost,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(9)],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => MaintenanceEntry.validateCost(v ?? ''),
                onChanged: (v) => _set(_entry.copyWith(totalCost: v)),
                decoration: const InputDecoration(
                  labelText: 'Coste total de todo',
                  suffixText: '€',
                  helperText: 'Lo repartimos entre los trabajos según precios medios de taller en España. '
                      'Es aproximado: en el historial se verá con «≈».',
                  helperMaxLines: 3,
                ),
              ),
            ],
            for (final entry in byCategory.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(color: c.textSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (idx, item) in entry.value.indexed) ...[
                      if (idx > 0) Divider(height: 1, color: c.border),
                      _ItemTile(
                        item: item,
                        state: _states[item.id],
                        line: e.lines.where((l) => l.key == item.id).firstOrNull,
                        enabled: !_saving,
                        byTotal: byTotal,
                        estimate: estimates[item.id],
                        onToggle: () => _set(_entry.toggle(item)),
                        onCost: (v) => _set(_entry.updateLine(item.id, (l) => l.copyWith(cost: v))),
                        onAddPhoto: () => _addPhoto(_entry.lines.firstWhere((l) => l.key == item.id)),
                        onRemovePhoto: (id) => _set(_entry.updateLine(
                          item.id,
                          (l) => l.copyWith(photos: [for (final p in l.photos) if (p.localId != id) p]),
                        )),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // ── Otros trabajos ────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(
                'OTROS TRABAJOS',
                style: TextStyle(color: c.textSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
            ),
            for (final l in customLines) ...[
              _CustomLineCard(
                key: ValueKey(l.key),
                line: l,
                enabled: !_saving,
                byTotal: byTotal,
                estimate: estimates[l.key],
                onName: (v) => _set(_entry.updateLine(l.key, (x) => x.copyWith(name: v))),
                onCost: (v) => _set(_entry.updateLine(l.key, (x) => x.copyWith(cost: v))),
                onRemove: () => _set(_entry.removeLine(l.key)),
                onAddPhoto: () => _addPhoto(_entry.lines.firstWhere((x) => x.key == l.key)),
                onRemovePhoto: (id) => _set(_entry.updateLine(
                  l.key,
                  (x) => x.copyWith(photos: [for (final p in x.photos) if (p.localId != id) p]),
                )),
              ),
              const SizedBox(height: 10),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => _set(_entry.addCustom()),
                icon: const Icon(Icons.add),
                label: const Text('Añadir otro trabajo (reparación, revisión…)'),
              ),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Taller y observaciones (opcional)'),
            TextField(
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _set(_entry.copyWith(notes: v)),
              decoration: const InputDecoration(hintText: 'Ej.: Taller Pepe, cambiaron también la escobilla trasera'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.state,
    required this.line,
    required this.enabled,
    required this.byTotal,
    required this.estimate,
    required this.onToggle,
    required this.onCost,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final MaintenanceItem item;
  final ItemState? state;
  final EntryLine? line;
  final bool enabled;
  final bool byTotal;
  final double? estimate;
  final VoidCallback onToggle;
  final ValueChanged<String> onCost;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = line != null;
    final s = state;
    final status = s?.status ?? ItemStatus.unknown;
    final dotColor = switch (status) {
      ItemStatus.danger => c.danger,
      ItemStatus.warning => c.warning,
      ItemStatus.ok => c.ok,
      ItemStatus.unknown => null,
    };
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: selected ? primary.withValues(alpha: 0.05) : null,
      child: Column(
        children: [
          MergeSemantics(
            child: InkWell(
              onTap: enabled ? onToggle : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                child: Row(
                  children: [
                    Checkbox(value: selected, onChanged: enabled ? (_) => onToggle() : null),
                    ExcludeSemantics(child: Text(item.icon, style: const TextStyle(fontSize: 18))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                          Text(
                            s?.lastRecord != null ? 'Último: ${Fmt.date(s!.lastRecord!.performedAt)}' : 'Sin registrar',
                            style: TextStyle(color: c.textSoft, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (dotColor != null && status != ItemStatus.ok)
                      Semantics(
                        label: status.label,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (line != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _CostAndPhotos(
                line: line!,
                enabled: enabled,
                byTotal: byTotal,
                estimate: estimate,
                onCost: onCost,
                onAddPhoto: onAddPhoto,
                onRemovePhoto: onRemovePhoto,
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomLineCard extends StatelessWidget {
  const _CustomLineCard({
    super.key,
    required this.line,
    required this.enabled,
    required this.byTotal,
    required this.estimate,
    required this.onName,
    required this.onCost,
    required this.onRemove,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final EntryLine line;
  final bool enabled;
  final bool byTotal;
  final double? estimate;
  final ValueChanged<String> onName;
  final ValueChanged<String> onCost;
  final VoidCallback onRemove;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.name,
                  enabled: enabled,
                  autofocus: line.name.isEmpty,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => MaintenanceEntry.validateCustomName(v ?? ''),
                  onChanged: onName,
                  decoration: const InputDecoration(
                    labelText: '🔧  Trabajo',
                    hintText: 'Ej.: Cambio de escobillas',
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar este trabajo',
                icon: const Icon(Icons.close),
                onPressed: enabled ? onRemove : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CostAndPhotos(
              line: line,
              enabled: enabled,
              byTotal: byTotal,
              estimate: estimate,
              onCost: onCost,
              onAddPhoto: onAddPhoto,
              onRemovePhoto: onRemovePhoto,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostAndPhotos extends StatelessWidget {
  const _CostAndPhotos({
    required this.line,
    required this.enabled,
    required this.byTotal,
    required this.estimate,
    required this.onCost,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final EntryLine line;
  final bool enabled;

  /// Modo "solo sé el total": en vez del campo de coste se ve el reparto.
  final bool byTotal;
  final double? estimate;
  final ValueChanged<String> onCost;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final full = line.photos.length >= MaintenanceEntry.maxPhotosPerLine;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: byTotal
              ? Semantics(
                  label: estimate == null ? 'Sin coste' : 'Coste estimado ${Fmt.money(estimate!)}',
                  excludeSemantics: true,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Estimado', isDense: true),
                    child: Text(estimate == null ? '—' : '≈ ${Fmt.money(estimate!)}',
                        style: TextStyle(color: c.textMid, fontWeight: FontWeight.w600)),
                  ),
                )
              : TextFormField(
            key: ValueKey('${line.key}-cost'),
            initialValue: line.cost,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(9)],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => MaintenanceEntry.validateCost(v ?? ''),
            onChanged: onCost,
            decoration: const InputDecoration(labelText: 'Coste', suffixText: '€', isDense: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in line.photos)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(p.bytes, width: 52, height: 52, fit: BoxFit.cover,
                          semanticLabel: 'Foto de ${line.name.isEmpty ? 'este trabajo' : line.name}'),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        color: c.danger,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: enabled ? () => onRemovePhoto(p.localId) : null,
                          child: Semantics(
                            button: true,
                            label: 'Quitar foto',
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (!full)
                OutlinedButton.icon(
                  onPressed: enabled ? onAddPhoto : null,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Foto'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: c.textMid,
                    side: BorderSide(color: c.border),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
