import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/specs_repository.dart';
import '../../data/vehicle_repository.dart';
import '../../domain/vehicle.dart';
import '../../domain/vehicle_draft.dart';
import '../../domain/vehicle_specs.dart';
import 'vehicles_provider.dart';

enum SpecsStatus { none, loading, ready, failed }

const _unset = Object();

class AddVehicleState {
  const AddVehicleState({
    this.draft = const VehicleDraft(),
    this.stepIndex = 0,
    this.specs,
    this.specsStatus = SpecsStatus.none,
    this.specsError,
    this.saving = false,
    this.saveError,
  });

  final VehicleDraft draft;
  final int stepIndex;
  final VehicleSpecs? specs;
  final SpecsStatus specsStatus;
  final String? specsError;
  final bool saving;
  final String? saveError;

  List<WizardStep> get steps => draft.steps;
  WizardStep get step => steps[stepIndex.clamp(0, steps.length - 1)];
  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex >= steps.length - 1;
  bool get canContinue => draft.isStepValid(step) && specsStatus != SpecsStatus.loading;
  bool get isDirty => draft.hasStarted;

  AddVehicleState copyWith({
    VehicleDraft? draft,
    int? stepIndex,
    Object? specs = _unset,
    SpecsStatus? specsStatus,
    Object? specsError = _unset,
    bool? saving,
    Object? saveError = _unset,
  }) {
    return AddVehicleState(
      draft: draft ?? this.draft,
      stepIndex: stepIndex ?? this.stepIndex,
      specs: identical(specs, _unset) ? this.specs : specs as VehicleSpecs?,
      specsStatus: specsStatus ?? this.specsStatus,
      specsError: identical(specsError, _unset) ? this.specsError : specsError as String?,
      saving: saving ?? this.saving,
      saveError: identical(saveError, _unset) ? this.saveError : saveError as String?,
    );
  }
}

/// Estado del asistente. Se descarta al salir de la pantalla (autoDispose).
final addVehicleControllerProvider =
    AutoDisposeNotifierProvider<AddVehicleController, AddVehicleState>(AddVehicleController.new);

class AddVehicleController extends AutoDisposeNotifier<AddVehicleState> {
  bool _disposed = false;

  @override
  AddVehicleState build() {
    ref.onDispose(() => _disposed = true);
    return const AddVehicleState();
  }

  /// Tras un `await` el usuario puede haber salido del asistente: entonces
  /// no hay estado que actualizar.
  void _set(AddVehicleState Function(AddVehicleState s) change) {
    if (!_disposed) state = change(state);
  }

  // ── Datos ─────────────────────────────────────────────────
  void selectType(VehicleType t) {
    // El tipo cambia el plan y la ficha: se descarta la ficha anterior.
    final changed = t != state.draft.type;
    state = state.copyWith(
      draft: state.draft.withType(t),
      specs: changed ? null : state.specs,
      specsStatus: changed ? SpecsStatus.none : state.specsStatus,
      specsError: null,
    );
  }

  void update(VehicleDraft Function(VehicleDraft d) change) {
    state = state.copyWith(draft: change(state.draft), saveError: null);
  }

  // ── Navegación ────────────────────────────────────────────
  void next() {
    if (!state.canContinue || state.isLast) return;
    state = state.copyWith(stepIndex: state.stepIndex + 1, saveError: null);
  }

  /// Devuelve false si ya estaba en el primer paso.
  bool back() {
    if (state.isFirst) return false;
    state = state.copyWith(stepIndex: state.stepIndex - 1, saveError: null);
    return true;
  }

  // ── Ficha técnica ─────────────────────────────────────────
  Future<void> generateSpecs() async {
    if (state.specsStatus == SpecsStatus.loading) return;
    state = state.copyWith(specsStatus: SpecsStatus.loading, specsError: null);
    try {
      final specs = await ref.read(specsRepositoryProvider).generate(state.draft);
      _set((s) => s.copyWith(specs: specs, specsStatus: SpecsStatus.ready));
    } on DataFailure catch (e) {
      _set((s) => s.copyWith(specsStatus: SpecsStatus.failed, specsError: e.message));
    }
  }

  void startManualSpecs() {
    state = state.copyWith(
      specs: const VehicleSpecs(source: SpecsSource.manual),
      specsStatus: SpecsStatus.ready,
      specsError: null,
    );
  }

  void setSpec(String key, String value) {
    final current = state.specs;
    if (current == null) return;
    state = state.copyWith(specs: current.withValue(key, value));
  }

  void clearSpecs() {
    state = state.copyWith(specs: null, specsStatus: SpecsStatus.none, specsError: null);
  }

  // ── Guardar ───────────────────────────────────────────────
  /// Devuelve el id del vehículo creado, o null si ha fallado (el error
  /// queda en `saveError`).
  Future<String?> save() async {
    if (state.saving || !state.draft.isComplete()) return null;
    state = state.copyWith(saving: true, saveError: null);
    // Que el guardado termine (y refresque la lista) aunque se salga de la pantalla.
    final keepAlive = ref.keepAlive();
    try {
      final id = await ref.read(vehicleRepositoryProvider).createVehicle(
            state.draft,
            specs: state.specsStatus == SpecsStatus.ready ? state.specs : null,
          );
      ref.invalidate(vehiclesProvider);
      return id;
    } on DataFailure catch (e) {
      _set((s) => s.copyWith(saveError: e.message));
      return null;
    } finally {
      _set((s) => s.copyWith(saving: false));
      keepAlive.close();
    }
  }
}
