import 'package:flutter_test/flutter_test.dart';
import 'package:mantenitrak/features/sharing/domain/share_code.dart';
import 'package:mantenitrak/features/vehicles/domain/vehicle.dart';

void main() {
  group('Código', () {
    test('normaliza mayúsculas, espacios y guiones', () {
      expect(ShareCode.normalize(' abc 23-4 '), 'ABC234');
    });

    test('valida longitud y alfabeto (sin 0, 1, I, L ni O)', () {
      expect(ShareCode.validate('ABC234'), isNull);
      expect(ShareCode.validate('abc 234'), isNull);
      expect(ShareCode.validate(''), 'Escribe el código');
      expect(ShareCode.validate('ABC23'), contains('6'));
      expect(ShareCode.validate('ABC230'), contains('no llevan'));
      expect(ShareCode.validate('OIL234'), contains('no llevan'));
    });

    test('formato para dictar', () {
      expect(ShareCode.pretty('ABC234'), 'ABC 234');
    });
  });

  group('QR', () {
    test('el enlace de la app y el código a secas', () {
      expect(ShareCode.fromScan('mantenitrak://app/join/ABC234'), 'ABC234');
      expect(ShareCode.fromScan(ShareCode.link('XYZ789')), 'XYZ789');
      expect(ShareCode.fromScan('mantenitrak://join?code=abc234'), 'ABC234');
      expect(ShareCode.fromScan('  abc234 '), 'ABC234');
    });

    test('rechaza QR de otras cosas', () {
      expect(ShareCode.fromScan('https://example.com/join/ABC234'), isNull);
      expect(ShareCode.fromScan('WIFI:S:casa;T:WPA;P:1234;;'), isNull);
      expect(ShareCode.fromScan('mantenitrak://app/join/'), isNull);
      expect(ShareCode.fromScan(null), isNull);
    });

    test('el mensaje para enviar lleva el código y el enlace', () {
      final m = ShareCode.message(vehicleName: 'Seat Ibiza', code: 'ABC234', expiresAt: DateTime(2026, 11, 18));
      expect(m, contains('ABC 234'));
      expect(m, contains('mantenitrak://app/join/ABC234'));
      expect(m, contains('18 nov 2026'));
    });
  });

  group('Invitación y personas', () {
    test('etiqueta de caducidad', () {
      final now = DateTime(2026, 11, 11, 10);
      expect(ShareInvite(code: 'ABC234', expiresAt: DateTime(2026, 11, 11, 23)).expiryLabel(now), 'Caduca hoy');
      expect(ShareInvite(code: 'ABC234', expiresAt: DateTime(2026, 11, 12, 9)).expiryLabel(now), 'Caduca mañana');
      expect(ShareInvite(code: 'ABC234', expiresAt: DateTime(2026, 11, 18, 9)).expiryLabel(now), startsWith('Caduca en 7 días'));
    });

    test('lee la fila de vehicle_members', () {
      final m = VehicleMember.fromJson({
        'user_id': 'u2',
        'display_name': '  Ana López ',
        'role': 'mechanic',
        'joined_at': '2026-11-01T10:00:00Z',
        'is_me': false,
      });
      expect(m.name, 'Ana López');
      expect(m.initials, 'AL');
      expect(m.role, AccessRole.mechanic);
      expect(m.joinedAt, isNotNull);
      final owner = VehicleMember.fromJson({'user_id': 'u1', 'display_name': null, 'role': 'owner', 'is_me': true});
      expect(owner.role, AccessRole.owner);
      expect(owner.name, 'Usuario sin nombre');
    });
  });
}
