import '../../vehicles/domain/vehicle.dart';

/// Periodicidad de la ITV en España (Real Decreto 920/2017, art. 6) para
/// vehículos de uso particular.
///
/// La edad se cuenta desde el año de matriculación. Como la app solo
/// guarda el año, el cálculo es aproximado en el año en que cambia el
/// tramo (p. ej. el año en que un coche cumple 10).
abstract final class ItvRules {
  /// Años hasta la primera ITV (0 = desde el primer año).
  static int firstAfterYears(VehicleType type) => switch (type) {
        VehicleType.furgoneta => 2,
        VehicleType.camion || VehicleType.autobus => 1,
        _ => 4,
      };

  /// Meses hasta la siguiente ITV si la anterior se pasó con [ageYears]
  /// años. null si el tipo no pasa ITV (barcos: tienen su propia
  /// inspección, fuera de esta app).
  static int? intervalMonths(VehicleType type, int ageYears) => switch (type) {
        // Motos, cuadriciclos y quads: cada 2 años, siempre.
        VehicleType.moto || VehicleType.quad => 24,
        // Mercancías < 3.500 kg: bienal hasta 6, anual hasta 10, semestral después.
        VehicleType.furgoneta => ageYears < 6 ? 24 : (ageYears < 10 ? 12 : 6),
        // Mercancías > 3.500 kg: anual hasta 10, semestral después.
        VehicleType.camion => ageYears < 10 ? 12 : 6,
        // Autobuses: anual hasta 5, semestral después.
        VehicleType.autobus => ageYears < 5 ? 12 : 6,
        VehicleType.barco => null,
        // Turismos, 4x4 y autocaravanas: bienal hasta 10, anual después.
        _ => ageYears < 10 ? 24 : 12,
      };

  /// Explicación corta de la regla para el tipo.
  static String describe(VehicleType type) => switch (type) {
        VehicleType.moto || VehicleType.quad => 'Primera a los 4 años y después cada 2 años.',
        VehicleType.furgoneta =>
          'Furgonetas de mercancías: primera a los 2 años; cada 2 años hasta los 6, cada año hasta los 10 y '
              'cada 6 meses después. Si es de pasajeros (como un turismo), elige el tipo «Coche».',
        VehicleType.camion => 'Cada año hasta los 10 años y cada 6 meses después.',
        VehicleType.autobus => 'Cada año hasta los 5 años y cada 6 meses después.',
        VehicleType.barco => 'Las embarcaciones no pasan ITV.',
        _ => 'Primera a los 4 años; cada 2 años hasta los 10 y después cada año.',
      };

  /// Edad aproximada (años completos) en una fecha. null si no se sabe el año.
  static int? ageAt(Vehicle v, DateTime date) => v.year > 0 ? (date.year - v.year).clamp(0, 200) : null;

  /// Año aproximado de la primera ITV. null si no se sabe el año.
  static int? firstItvYear(Vehicle v) => v.year > 0 ? v.year + firstAfterYears(v.type) : null;
}
