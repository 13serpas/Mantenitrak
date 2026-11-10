/// Validadores de formulario. Devuelven el mensaje de error o null.
abstract final class Validators {
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _letterRe = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
  static final _digitRe = RegExp(r'\d');

  static const minPasswordLength = 8;

  static String? name(String? v) =>
      (v ?? '').trim().isEmpty ? 'Introduce tu nombre' : null;

  static String? email(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Introduce tu email';
    if (!_emailRe.hasMatch(t)) return 'El email no es válido';
    return null;
  }

  /// Para iniciar sesión: solo comprobamos que no esté vacía.
  static String? password(String? v) =>
      (v ?? '').isEmpty ? 'Introduce tu contraseña' : null;

  /// Para crear o cambiar contraseña.
  static String? newPassword(String? v) {
    final t = v ?? '';
    if (t.length < minPasswordLength) {
      return 'Mínimo $minPasswordLength caracteres';
    }
    if (!_letterRe.hasMatch(t) || !_digitRe.hasMatch(t)) {
      return 'Combina letras y números';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) =>
      (v) => (v ?? '') != original() ? 'Las contraseñas no coinciden' : null;
}
