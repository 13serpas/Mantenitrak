import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/auth_failure.dart';

enum SignUpResult { signedIn, confirmationSent }

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

/// Única puerta de entrada a Supabase Auth. Todas las llamadas lanzan
/// [AuthFailure] (nunca AuthException) para que la UI no dependa de Supabase.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email.trim(), password: password));

  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _guard(() => _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': name.trim()},
          emailRedirectTo: Env.authRedirectUrl,
        ));

    // Con la confirmación de email activa, Supabase NO devuelve error si el
    // email ya existe (para no revelar qué emails están registrados): devuelve
    // un usuario sin identidades.
    if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
      throw const AuthFailure(AuthFailureType.emailInUse);
    }
    return res.session != null ? SignUpResult.signedIn : SignUpResult.confirmationSent;
  }

  Future<void> resendConfirmation(String email) => _guard(() => _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: Env.authRedirectUrl,
      ));

  Future<void> sendPasswordReset(String email) => _guard(
        () => _auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirectUrl),
      );

  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  /// Abre el navegador con Google; al volver, supabase_flutter crea la
  /// sesión y el router redirige solo.
  Future<void> signInWithGoogle() => _guard(
        () => _auth.signInWithOAuth(OAuthProvider.google, redirectTo: Env.authRedirectUrl),
      );

  Future<void> signOut() => _guard(() => _auth.signOut());

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthException catch (e) {
      throw AuthFailure.fromAuthException(e);
    } on AuthFailure {
      rethrow;
    } on Exception catch (e) {
      // Fallos de red que no llegan envueltos como AuthException.
      // (Los Error de programación no se capturan: deben verse.)
      throw AuthFailure(AuthFailureType.network, e.toString());
    }
  }
}
