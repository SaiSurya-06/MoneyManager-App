import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/database/daos/user_profile_dao.dart';
import 'package:money_manager/core/database/database.dart';
import 'package:money_manager/models/user_profile.dart';
import 'package:money_manager/providers/auth_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    AppDatabase.setMockDatabase(db);
    FlutterSecureStorage.setMockInitialValues({});
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, preferred_currency TEXT NOT NULL,
        pin_hash TEXT NOT NULL, biometric_enabled INTEGER NOT NULL,
        theme_preference TEXT NOT NULL, reminder_enabled INTEGER NOT NULL,
        reminder_time TEXT NOT NULL
      )
    ''');
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  Future<UserProfile> legacyProfile({String? salt}) async {
    final dao = UserProfileDao();
    final profile = UserProfile(
      name: 'Test', preferredCurrency: 'INR',
      pinHash: sha256.convert(utf8.encode('1234${salt ?? ''}')).toString(),
      biometricEnabled: false, themePreference: 'dark',
      reminderEnabled: false, reminderTime: '20:00',
    );
    final id = await dao.insertProfile(profile, saveCredentials: (id) async {
      if (salt != null) {
        await const FlutterSecureStorage().write(key: 'user_pin_salt_$id', value: salt);
      }
    });
    return profile.copyWith(id: id);
  }

  test('existing salted PIN upgrades and remains usable for sign-in and confirmation', () async {
    final original = await legacyProfile(salt: 'previous-device-secret');
    final auth = AuthNotifier();
    addTearDown(auth.dispose);
    await auth.checkProfile();

    expect(await auth.verifyPin('1234'), isTrue);
    final dao = UserProfileDao();
    final updated = (await dao.getProfileById(original.id!))!;
    expect(updated.pinHash, startsWith('pbkdf2-sha256-v1:'));
    await dao.updateProfile(original.copyWith(name: 'Renamed'));
    expect((await dao.getProfileById(original.id!))!.pinHash, updated.pinHash);
    expect(await auth.verifyPin('1234', authenticateSession: false), isTrue);

    auth.logout();
    expect(await auth.verifyPin('1234', authenticateSession: false), isFalse);
    expect(await auth.verifyPin('1234'), isTrue);
  });

  test('a failed upgrade leaves the previous PIN usable', () async {
    final original = await legacyProfile(salt: 'previous-device-secret');
    await db.execute('''
      CREATE TRIGGER reject_pin_upgrade BEFORE UPDATE OF pin_hash ON user_profile
      BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END
    ''');
    final auth = AuthNotifier();
    addTearDown(auth.dispose);
    await auth.checkProfile();
    expect(await auth.verifyPin('1234'), isTrue);
    expect((await UserProfileDao().getProfileById(original.id!))!.pinHash, original.pinHash);
    auth.logout();
    await db.execute('DROP TRIGGER reject_pin_upgrade');
    expect(await auth.verifyPin('1234'), isTrue);
    expect(auth.state.profile!.pinHash, startsWith('pbkdf2-sha256-v1:'));
  });

  test('failed attempts survive notifier restart and still lock the correct PIN', () async {
    final original = await legacyProfile();
    final auth = AuthNotifier();
    await auth.checkProfile();
    for (var i = 0; i < 4; i++) {
      expect(await auth.verifyPin('0000'), isFalse);
    }
    auth.dispose();

    final restarted = AuthNotifier();
    addTearDown(restarted.dispose);
    await restarted.checkProfile();
    expect(restarted.state.wrongAttempts, 4);
    expect(await restarted.verifyPin('0000'), isFalse);
    expect(restarted.state.lockedUntil, isNotNull);
    expect(await restarted.verifyPin('1234'), isFalse);

    await const FlutterSecureStorage().write(
      key: 'user_pin_attempts_${original.id}',
      value: jsonEncode({
        'attempts': 5,
        'until': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      }),
    );
    expect(await restarted.verifyPin('1234'), isTrue);
    expect(restarted.state.lockedUntil, isNull);
  });
}
