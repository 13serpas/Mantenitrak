abstract final class Routes {
  static const onboarding = '/onboarding';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot';
  static const resetPassword = '/auth/reset-password';
  static const home = '/home';
  static const addVehicle = '/vehicles/add';

  /// [tab]: estado, que-hacer, combustible, gastos, historial o ficha.
  static String vehicleDetail(String id, {String? tab}) =>
      tab == null ? '/vehicles/$id' : '/vehicles/$id?tab=$tab';
  static String editVehicle(String id) => '/vehicles/$id/edit';

  /// [items]: trabajos ya marcados al abrir (p. ej. desde "¿Qué hacer?").
  static String addMaintenance(String id, {Iterable<String> items = const []}) =>
      items.isEmpty ? '/vehicles/$id/maintenance' : '/vehicles/$id/maintenance?items=${items.join(',')}';
  static String addFuel(String id) => '/vehicles/$id/fuel/add';
  static String addExpense(String id) => '/vehicles/$id/expenses/add';
  static String shareVehicle(String id) => '/vehicles/$id/share';

  /// Unirse a un vehículo compartido. El QR abre /join/CODIGO
  /// (mantenitrak://app/join/CODIGO); desde el menú se abre /join.
  static const joinBase = '/join';
  static String joinVehicle([String? code]) => code == null ? joinBase : '$joinBase/$code';

  /// Añade `?from=` para volver a la ruta original tras iniciar sesión
  /// (p. ej. un enlace /join/ABC123 abierto sin sesión).
  static String withFrom(String path, String? from) =>
      from == null ? path : '$path?from=${Uri.encodeComponent(from)}';

  /// Solo aceptamos rutas internas, nunca URLs externas ni rutas de auth.
  static String? safeFrom(String? from) {
    if (from == null || !from.startsWith('/') || from.startsWith('//')) {
      return null;
    }
    if (from.startsWith('/auth') || from == onboarding) return null;
    return from;
  }
}
