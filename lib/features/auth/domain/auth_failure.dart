import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFailureType {
  invalidCredentials,
  emailNotConfirmed,
  emailInUse,
  weakPassword,
  samePassword,
  rateLimited,
  network,
  unknown,
}

/// Error de autenticación ya traducido para mostrar al usuario.
class AuthFailure implements Exception {
  const AuthFailure(this.type, [this.detail]);

  factory AuthFailure.fromAuthException(AuthException e) => AuthFailure(
        classify(
          code: e.code,
          message: e.message,
          statusCode: e.statusCode,
          retryable: e is AuthRetryableFetchException,
        ),
        e.message,
      );

  final AuthFailureType type;

  /// Mensaje original de Supabase, útil para logs.
  final String? detail;

  String get message => switch (type) {
        AuthFailureType.invalidCredentials => 'Email o contraseña incorrectos.',
        AuthFailureType.emailNotConfirmed =>
          'Aún no has confirmado tu email. Revisa tu bandeja de entrada.',
        AuthFailureType.emailInUse => 'Ya existe una cuenta con este email.',
        AuthFailureType.weakPassword =>
          'La contraseña es demasiado débil. Usa al menos 8 caracteres con letras y números.',
        AuthFailureType.samePassword =>
          'La nueva contraseña debe ser distinta de la anterior.',
        AuthFailureType.rateLimited =>
          'Demasiados intentos. Espera un momento y vuelve a probar.',
        AuthFailureType.network =>
          'No hay conexión con el servidor. Comprueba tu conexión a internet.',
        AuthFailureType.unknown => 'Ha ocurrido un error inesperado. Inténtalo de nuevo.',
      };

  /// Clasifica por código de error de Supabase y, si no viene, por el texto.
  static AuthFailureType classify({
    String? code,
    required String message,
    String? statusCode,
    bool retryable = false,
  }) {
    if (retryable) return AuthFailureType.network;

    switch (code) {
      case 'invalid_credentials':
        return AuthFailureType.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailureType.emailNotConfirmed;
      case 'user_already_exists':
      case 'email_exists':
        return AuthFailureType.emailInUse;
      case 'weak_password':
        return AuthFailureType.weakPassword;
      case 'same_password':
        return AuthFailureType.samePassword;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailureType.rateLimited;
    }
    if (statusCode == '429') return AuthFailureType.rateLimited;

    final m = message.toLowerCase();
    if (m.contains('invalid login credentials')) return AuthFailureType.invalidCredentials;
    if (m.contains('email not confirmed')) return AuthFailureType.emailNotConfirmed;
    if (m.contains('already registered')) return AuthFailureType.emailInUse;
    if (m.contains('password should')) return AuthFailureType.weakPassword;
    if (m.contains('different from the old')) return AuthFailureType.samePassword;
    if (m.contains('rate limit')) return AuthFailureType.rateLimited;
    return AuthFailureType.unknown;
  }

  @override
  String toString() => 'AuthFailure($type, $detail)';
}
