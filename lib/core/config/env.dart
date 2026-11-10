import 'package:flutter/foundation.dart';

/// Configuración inyectada en compilación con
/// `flutter run --dart-define-from-file=env.json`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Esquema propio para volver a la app desde los correos de Supabase
  /// (confirmación de cuenta, recuperación de contraseña) y desde Google.
  /// Debe estar en Supabase → Authentication → URL Configuration → Redirect URLs.
  static const mobileAuthRedirect = 'mantenitrak://auth-callback';

  static String get authRedirectUrl =>
      kIsWeb ? '${Uri.base.origin}/' : mobileAuthRedirect;
}
