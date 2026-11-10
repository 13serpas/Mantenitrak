import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Se sobrescribe en main() con la instancia ya cargada, para poder
/// leer preferencias de forma síncrona (tema, onboarding visto…).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Sobrescribir en main()'),
);
