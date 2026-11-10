/// Formatos en español sin depender de `intl` (cuya versión fija el SDK de
/// Flutter y suele chocar con otras dependencias).
abstract final class Fmt {
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// 45000 → "45.000"
  static String thousands(num n) {
    final negative = n < 0;
    final digits = n.abs().round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  /// 6.25 → "6,3" (con [decimals] = 1)
  static String decimal(double n, [int decimals = 1]) =>
      n.toStringAsFixed(decimals).replaceAll('.', ',');

  static String km(num n) => '${thousands(n)} km';

  static String euros(num n) => '${thousands(n)} €';

  /// Importe con céntimos solo si los tiene: "89 €", "89,90 €", "1.234,50 €".
  static String money(num n) {
    final cents = (n * 100).round();
    final whole = cents ~/ 100;
    final frac = cents.remainder(100).abs();
    return frac == 0 ? '${thousands(whole)} €' : '${thousands(whole)},${frac.toString().padLeft(2, '0')} €';
  }

  /// 2026-11-10 → "10 nov 2026"
  static String date(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  /// Fecha de hoy como la espera una columna DATE.
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
