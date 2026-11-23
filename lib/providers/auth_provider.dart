import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../core/database/daos/user_profile_dao.dart';
import '../models/user_profile.dart';
import '../core/notifications/notification_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';

const _pinHashPrefix = 'pbkdf2-sha256-v1:';

String _derivePinHash((String, String) input) {
  // The format version fixes these parameters for already enrolled PINs.
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(base64Url.decode(input.$2), 100000, 32));
  return '$_pinHashPrefix${base64Url.encode(derivator.process(Uint8List.fromList(utf8.encode(input.$1))))}';
}

bool _matchesHash(String actual, String expected) {
  if (actual.length != expected.length) return false;
  var difference = 0;
  for (var i = 0; i < actual.length; i++) {
    difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return difference == 0;
}

enum AuthStatus {
  undetermined,
  pinSetupRequired,
  unauthenticated,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final List<UserProfile> profiles;
  final String? errorMessage;
  final bool isBiometricAvailable;
  final int wrongAttempts;
  final DateTime? lockedUntil;

  AuthState({
    required this.status,
    this.profile,
    this.profiles = const [],
    this.errorMessage,
    this.isBiometricAvailable = false,
    this.wrongAttempts = 0,
    this.lockedUntil,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    List<UserProfile>? profiles,
    String? errorMessage,
    bool? isBiometricAvailable,
    int? wrongAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    bool clearProfile = false,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      profiles: profiles ?? this.profiles,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      wrongAttempts: wrongAttempts ?? this.wrongAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final UserProfileDao _profileDao = UserProfileDao();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _verifyingPin = false;
  bool _settingUpPin = false;

  AuthNotifier() : super(AuthState(status: AuthStatus.undetermined)) {
    checkProfile();
  }

  Future<void> _scheduleReminderIfEnabled(UserProfile? profile) async {
    if (profile != null && profile.reminderEnabled) {
      try {
        final timeParts = profile.reminderTime.split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          await NotificationService.instance.scheduleDailyReminder(hour, minute);
        }
      } catch (e) {
        AppLogger.w('Failed to schedule daily reminder', error: e, tag: 'AuthProvider');
      }
    } else {
      try {
        await NotificationService.instance.cancelDailyReminder();
      } catch (e) {
        AppLogger.w('Failed to cancel daily reminder', error: e, tag: 'AuthProvider');
      }
    }
  }

  Future<void> checkProfile() async {
    try {
      final profiles = await _profileDao.getAllProfiles();
      final isBioAvailable = await _checkBiometricsAvailability();
      
      if (profiles.isEmpty) {
        state = AuthState(
          status: AuthStatus.pinSetupRequired,
          profiles: [],
          isBiometricAvailable: isBioAvailable,
        );
      } else {
        final selectedId = state.profile?.id;
        final selected = profiles.where((profile) => profile.id == selectedId);
        final activeProfile =
            selected.isNotEmpty ? selected.first : (profiles.length == 1 ? profiles.first : null);
        var throttle = (attempts: 0, until: null as DateTime?);
        final profileId = activeProfile?.id;
        if (profileId != null) {
          try {
            throttle = await _readThrottle(profileId);
          } catch (e) {
            AppLogger.w('Could not load PIN lockout state', error: e, tag: 'AuthProvider');
          }
        }
        state = AuthState(
          status: AuthStatus.unauthenticated,
          profile: activeProfile,
          wrongAttempts: throttle.attempts,
          lockedUntil: throttle.until,
          profiles: profiles,
          isBiometricAvailable: isBioAvailable,
        );
        if (activeProfile != null) {
          await _scheduleReminderIfEnabled(activeProfile);
        }
      }
    } catch (e, stack) {
      AppLogger.e('Database error checking profile', error: e, stackTrace: stack, tag: 'AuthProvider');
      state = state.copyWith(errorMessage: 'Database error: $e');
    }
  }

  Future<bool> _checkBiometricsAvailability() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      AppLogger.w('Biometrics check error', error: e, tag: 'AuthProvider');
      return false;
    }
  }

  void selectProfile(UserProfile profile) {
    state = state.copyWith(
      profile: profile,
      status: AuthStatus.unauthenticated,
      wrongAttempts: 0,
      clearLockedUntil: true,
    );
    _scheduleReminderIfEnabled(profile);
  }

  void showSelector() {
    state = state.copyWith(
      profile: null,
      clearProfile: true,
      status: AuthStatus.unauthenticated,
      wrongAttempts: 0,
      clearLockedUntil: true,
    );
  }

  void startCreateProfile() {
    state = state.copyWith(
      status: AuthStatus.pinSetupRequired,
      profile: null,
      clearProfile: true,
    );
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<bool> setupPin(String name, String currency, String pin) async {
    if (_settingUpPin) return false;
    _settingUpPin = true;
    try {
      final salt = _generateSalt();
      final pinHash = await compute(_derivePinHash, (pin, salt));
      
      final profile = UserProfile(
        name: name,
        preferredCurrency: currency,
        pinHash: pinHash,
        biometricEnabled: false,
        themePreference: AppConstants.defaultTheme,
        reminderEnabled: true,
        reminderTime: AppConstants.defaultReminderTime,
      );

      final id = await _profileDao.insertProfile(
        profile,
        saveCredentials: (id) async {
          await _secureStorage.delete(key: _attemptKey(id));
          await _secureStorage.write(key: _currentSaltKey(id, pinHash), value: salt);
        },
      );
      final createdProfile = profile.copyWith(id: id);

      final profiles = await _profileDao.getAllProfiles();
      if (!mounted) return false;
      state = state.copyWith(
        profile: createdProfile,
        profiles: profiles,
        status: AuthStatus.authenticated,
        wrongAttempts: 0,
        clearLockedUntil: true,
        clearErrorMessage: true,
      );
      await _scheduleReminderIfEnabled(createdProfile);
      return true;
    } catch (e, stack) {
      AppLogger.e('Failed to save PIN during setup', error: e, stackTrace: stack, tag: 'AuthProvider');
      if (mounted) state = state.copyWith(errorMessage: 'Failed to save PIN.');
      return false;
    } finally {
      _settingUpPin = false;
    }
  }

  String _currentSaltKey(int id, String verifier) => '${AppConstants.securePinSaltKey}_${id}_$verifier';

  String _attemptKey(int id) => 'user_pin_attempts_$id';

  Future<({int attempts, DateTime? until})> _readThrottle(int id) async {
    final value = await _secureStorage.read(key: _attemptKey(id));
    if (value == null) return (attempts: 0, until: null);
    final data = jsonDecode(value) as Map<String, dynamic>;
    final until = data['until'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(data['until'] as int);
    if (until != null && !until.isAfter(DateTime.now())) {
      return (attempts: 0, until: null);
    }
    return (attempts: data['attempts'] as int, until: until);
  }

  Future<bool> verifyPin(String pin, {bool authenticateSession = true}) async {
    final profile = state.profile;
    final id = profile?.id;
    if (profile == null || id == null || _verifyingPin) return false;
    final startedStatus = state.status;
    if (!authenticateSession && startedStatus != AuthStatus.authenticated) return false;

    bool isCurrent() => mounted &&
        state.status == startedStatus &&
        state.profile?.id == id &&
        state.profile?.pinHash == profile.pinHash;

    _verifyingPin = true;
    try {
      final throttle = await _readThrottle(id);
      if (!isCurrent()) return false;
      if (throttle.until != null) {
        final remaining = throttle.until!.difference(DateTime.now());
        state = state.copyWith(
          wrongAttempts: throttle.attempts,
          lockedUntil: throttle.until,
          errorMessage: 'App locked. Try again in ${remaining.inMinutes} minutes ${remaining.inSeconds % 60} seconds.',
        );
        return false;
      }

      final saved = await _profileDao.getProfileById(id);
      if (saved == null || !isCurrent()) return false;
      final legacy = !saved.pinHash.startsWith(_pinHashPrefix);
      final salt = await _secureStorage.read(
        key: legacy ? '${AppConstants.securePinSaltKey}_$id' : _currentSaltKey(id, saved.pinHash),
      );
      if (!legacy && (salt == null || salt.isEmpty)) {
        throw StateError('Device PIN credentials unavailable.');
      }
      final matches = legacy
          ? _matchesHash(sha256.convert(utf8.encode(pin)).toString(), saved.pinHash) ||
              (salt != null &&
                  _matchesHash(sha256.convert(utf8.encode(pin + salt)).toString(), saved.pinHash))
          : _matchesHash(await compute(_derivePinHash, (pin, salt!)), saved.pinHash);
      if (!isCurrent()) return false;

      if (!matches) {
        final attempts = throttle.attempts + 1;
        final until = attempts >= 5
            ? DateTime.now().add(const Duration(minutes: 30))
            : null;
        await _secureStorage.write(
          key: _attemptKey(id),
          value: jsonEncode({'attempts': attempts, 'until': until?.millisecondsSinceEpoch}),
        );
        if (!isCurrent()) return false;
        state = state.copyWith(
          wrongAttempts: attempts,
          lockedUntil: until,
          clearLockedUntil: until == null,
          errorMessage: until == null
              ? 'Incorrect PIN. Please try again. (${5 - attempts} attempts remaining)'
              : 'Too many failed attempts. App locked for 30 minutes.',
        );
        if (until != null) await NotificationService.instance.showLockoutAlert();
        return false;
      }

      await _secureStorage.delete(key: _attemptKey(id));
      var verifier = saved.pinHash;
      if (legacy && isCurrent()) {
        try {
          final newSalt = _generateSalt();
          final hash = await compute(_derivePinHash, (pin, newSalt));
          if (!isCurrent()) return false;
          // The original verifier and salt remain usable if this upgrade fails.
          await _secureStorage.write(key: _currentSaltKey(id, hash), value: newSalt);
          final changed = await _profileDao.replacePinHash(id, saved.pinHash, hash);
          if (changed == 0) return false;
          verifier = hash;
        } catch (e) {
          AppLogger.w('PIN upgrade will retry on a later successful verification', error: e, tag: 'AuthProvider');
        }
      }
      if (!isCurrent()) return false;
      final current = state;
      final selected = current.profile!.copyWith(pinHash: verifier);
      state = current.copyWith(
        status: authenticateSession ? AuthStatus.authenticated : current.status,
        profile: selected,
        profiles: current.profiles.map((entry) => entry.id == id ? selected : entry).toList(),
        wrongAttempts: 0,
        clearLockedUntil: true,
        clearErrorMessage: true,
      );
      if (authenticateSession) await _scheduleReminderIfEnabled(selected);
      return true;
    } catch (e) {
      AppLogger.w('PIN verification unavailable', error: e, tag: 'AuthProvider');
      if (isCurrent()) {
        state = state.copyWith(errorMessage: 'Could not verify your PIN. Please try again.');
      }
      return false;
    } finally {
      _verifyingPin = false;
    }
  }

  Future<bool> authenticateBiometrically() async {
    final profile = state.profile;
    if (profile == null || !profile.biometricEnabled) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your Money Manager',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        state = state.copyWith(status: AuthStatus.authenticated);
        await _scheduleReminderIfEnabled(profile);
        return true;
      }
      return false;
    } catch (e, stack) {
      AppLogger.e('Biometric authentication failed', error: e, stackTrace: stack, tag: 'AuthProvider');
      state = state.copyWith(errorMessage: 'Biometric authentication failed: $e');
      return false;
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    try {
      await _profileDao.updateProfile(updatedProfile);
      final saved = await _profileDao.getProfileById(updatedProfile.id!);
      if (saved == null || state.profile?.id != saved.id) return;
      state = state.copyWith(
        profile: saved,
        profiles: state.profiles.map((entry) => entry.id == saved.id ? saved : entry).toList(),
      );
      await _scheduleReminderIfEnabled(saved);
    } catch (e, stack) {
      AppLogger.e('Failed to update profile', error: e, stackTrace: stack, tag: 'AuthProvider');
      state = state.copyWith(errorMessage: 'Failed to update profile: $e');
    }
  }

  void logout() {
    if (state.profile != null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } else {
      state = state.copyWith(status: AuthStatus.pinSetupRequired);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
