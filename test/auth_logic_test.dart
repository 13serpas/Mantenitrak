import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/core/router/routes.dart';
import 'package:mantenitrak/features/auth/domain/auth_failure.dart';
import 'package:mantenitrak/shared/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('ana@'), isNotNull);
      expect(Validators.email('ana@x.c'), isNotNull);
      expect(Validators.email('  ana@correo.es '), isNull);
    });

    test('newPassword exige 8 caracteres con letras y números', () {
      expect(Validators.newPassword('abc12'), isNotNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('coche2024'), isNull);
    });

    test('confirmPassword', () {
      final v = Validators.confirmPassword(() => 'coche2024');
      expect(v('coche2025'), isNotNull);
      expect(v('coche2024'), isNull);
    });
  });

  group('AuthFailure.classify', () {
    AuthFailureType c({String? code, String message = '', String? status, bool retry = false}) =>
        AuthFailure.classify(code: code, message: message, statusCode: status, retryable: retry);

    test('por código', () {
      expect(c(code: 'invalid_credentials'), AuthFailureType.invalidCredentials);
      expect(c(code: 'email_not_confirmed'), AuthFailureType.emailNotConfirmed);
      expect(c(code: 'user_already_exists'), AuthFailureType.emailInUse);
      expect(c(code: 'weak_password'), AuthFailureType.weakPassword);
      expect(c(code: 'over_email_send_rate_limit'), AuthFailureType.rateLimited);
    });

    test('por mensaje cuando no hay código', () {
      expect(c(message: 'Invalid login credentials'), AuthFailureType.invalidCredentials);
      expect(c(message: 'Email not confirmed'), AuthFailureType.emailNotConfirmed);
      expect(c(message: 'User already registered'), AuthFailureType.emailInUse);
    });

    test('429 y red', () {
      expect(c(status: '429'), AuthFailureType.rateLimited);
      expect(c(retry: true, code: 'invalid_credentials'), AuthFailureType.network);
      expect(c(message: 'algo raro'), AuthFailureType.unknown);
    });
  });

  group('Routes.safeFrom', () {
    test('acepta rutas internas', () {
      expect(Routes.safeFrom('/join/ABC123'), '/join/ABC123');
    });
    test('rechaza externas, auth y vacías', () {
      expect(Routes.safeFrom(null), isNull);
      expect(Routes.safeFrom('https://evil.com'), isNull);
      expect(Routes.safeFrom('//evil.com'), isNull);
      expect(Routes.safeFrom('/auth/login'), isNull);
      expect(Routes.safeFrom(Routes.onboarding), isNull);
    });
    test('withFrom codifica', () {
      expect(Routes.withFrom('/auth/login', '/join/A B'), '/auth/login?from=%2Fjoin%2FA%20B');
      expect(Routes.withFrom('/auth/login', null), '/auth/login');
    });
  });
}
