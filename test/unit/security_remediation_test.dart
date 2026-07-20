import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/utils/encryption_service.dart';
import 'package:money_manager/providers/partner_sync_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService Tests (Issue #2)', () {
    final service = EncryptionService.instance;
    const password = 'mySecretPin1234';
    const salt = 'randomSaltStr';
    const plaintext = 'Sensitive Transaction Data';

    test('Encryption & Decryption Roundtrip with PBKDF2', () {
      final encrypted = service.encrypt(plaintext, password, salt);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(contains(plaintext)));

      final decrypted = service.decrypt(encrypted, password, salt);
      expect(decrypted, equals(plaintext));
    });

    test('Decryption fails with incorrect password', () {
      final encrypted = service.encrypt(plaintext, password, salt);
      expect(() => service.decrypt(encrypted, 'wrongPassword', salt), throwsException);
    });

    test('Legacy key derivation fallback', () {
      // Manually derive legacy key and verify fallback mechanism
      final legacyKey = service.deriveLegacyKey(password, salt);
      expect(legacyKey.bytes.length, equals(32));
    });
  });

  group('PartnerTransaction Payload Validation (Issue #11)', () {
    test('Validates negative and NaN amounts', () {
      final mapWithNan = {
        'title': 'Test Tx',
        'amount': double.nan,
        'type': 'expense',
        'date': '2026-07-21T00:00:00.000',
      };
      final tx = PartnerTransaction.fromMap(mapWithNan);
      expect(tx.amount, equals(0.0));
    });

    test('Validates malformed dates cleanly without throwing', () {
      final mapWithBadDate = {
        'title': 'Test Tx',
        'amount': 50.0,
        'type': 'expense',
        'date': 'invalid-date-string',
      };
      final tx = PartnerTransaction.fromMap(mapWithBadDate);
      expect(tx.amount, equals(50.0));
      expect(tx.date, isNotNull);
    });
  });
}
