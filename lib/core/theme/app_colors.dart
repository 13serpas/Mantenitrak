import 'package:flutter/material.dart';

/// Colores semánticos que Material no cubre (estados, combustible…).
/// Uso: `context.colors.textMid`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textMid,
    required this.textSoft,
    required this.border,
    required this.borderStrong,
    required this.surfaceAlt,
    required this.fuel,
    required this.fuelLight,
    required this.fuelBorder,
    required this.danger,
    required this.dangerLight,
    required this.dangerBorder,
    required this.warning,
    required this.warningLight,
    required this.warningBorder,
    required this.ok,
    required this.okLight,
    required this.okBorder,
  });

  final Color textMid, textSoft, border, borderStrong, surfaceAlt;
  final Color fuel, fuelLight, fuelBorder;
  final Color danger, dangerLight, dangerBorder;
  final Color warning, warningLight, warningBorder;
  final Color ok, okLight, okBorder;

  static const light = AppColors(
    textMid: Color(0xFF57534E),
    textSoft: Color(0xFFA8A29E),
    border: Color(0xFFE5E3DE),
    borderStrong: Color(0xFFD1CFC9),
    surfaceAlt: Color(0xFFF3F2EF),
    fuel: Color(0xFF0891B2),
    fuelLight: Color(0xFFECFEFF),
    fuelBorder: Color(0xFFA5F3FC),
    danger: Color(0xFFDC2626),
    dangerLight: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    warning: Color(0xFFD97706),
    warningLight: Color(0xFFFFFBEB),
    warningBorder: Color(0xFFFDE68A),
    ok: Color(0xFF16A34A),
    okLight: Color(0xFFF0FDF4),
    okBorder: Color(0xFFBBF7D0),
  );

  static const dark = AppColors(
    textMid: Color(0xFF9CA3AF),
    textSoft: Color(0xFF6B7280),
    border: Color(0xFF2E3244),
    borderStrong: Color(0xFF3D4460),
    surfaceAlt: Color(0xFF252836),
    fuel: Color(0xFF06B6D4),
    fuelLight: Color(0xFF0E3040),
    fuelBorder: Color(0xFF0E7490),
    danger: Color(0xFFF87171),
    dangerLight: Color(0xFF2D1515),
    dangerBorder: Color(0xFF7F1D1D),
    warning: Color(0xFFFBBF24),
    warningLight: Color(0xFF1C1400),
    warningBorder: Color(0xFF78350F),
    ok: Color(0xFF4ADE80),
    okLight: Color(0xFF052E16),
    okBorder: Color(0xFF166534),
  );

  @override
  AppColors copyWith({
    Color? textMid,
    Color? textSoft,
    Color? border,
    Color? borderStrong,
    Color? surfaceAlt,
    Color? fuel,
    Color? fuelLight,
    Color? fuelBorder,
    Color? danger,
    Color? dangerLight,
    Color? dangerBorder,
    Color? warning,
    Color? warningLight,
    Color? warningBorder,
    Color? ok,
    Color? okLight,
    Color? okBorder,
  }) {
    return AppColors(
      textMid: textMid ?? this.textMid,
      textSoft: textSoft ?? this.textSoft,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      fuel: fuel ?? this.fuel,
      fuelLight: fuelLight ?? this.fuelLight,
      fuelBorder: fuelBorder ?? this.fuelBorder,
      danger: danger ?? this.danger,
      dangerLight: dangerLight ?? this.dangerLight,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      warningBorder: warningBorder ?? this.warningBorder,
      ok: ok ?? this.ok,
      okLight: okLight ?? this.okLight,
      okBorder: okBorder ?? this.okBorder,
    );
  }

  /// Interpola de verdad para que el cambio claro/oscuro sea suave.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      textMid: l(textMid, other.textMid),
      textSoft: l(textSoft, other.textSoft),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      fuel: l(fuel, other.fuel),
      fuelLight: l(fuelLight, other.fuelLight),
      fuelBorder: l(fuelBorder, other.fuelBorder),
      danger: l(danger, other.danger),
      dangerLight: l(dangerLight, other.dangerLight),
      dangerBorder: l(dangerBorder, other.dangerBorder),
      warning: l(warning, other.warning),
      warningLight: l(warningLight, other.warningLight),
      warningBorder: l(warningBorder, other.warningBorder),
      ok: l(ok, other.ok),
      okLight: l(okLight, other.okLight),
      okBorder: l(okBorder, other.okBorder),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
