import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import '../constants/app_constants.dart';
import 'app_logger.dart';

class EncryptionService {
  static final EncryptionService instance = EncryptionService._internal();
  EncryptionService._internal();

  /// Derives a 32-byte key from password/PIN and salt using industry-standard PBKDF2-HMAC-SHA256.
  enc.Key deriveKey(String password, String salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(salt)),
        AppConstants.pbkdf2Iterations,
        AppConstants.pbkdf2KeyLength,
      ));
    final keyBytes = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return enc.Key(keyBytes);
  }

  /// Legacy SHA-256 key stretching (5,000 iterations) for backwards compatibility.
  enc.Key deriveLegacyKey(String password, String salt) {
    List<int> keyBytes = utf8.encode(password + salt);
    for (int i = 0; i < 5000; i++) {
      keyBytes = sha256.convert(keyBytes).bytes;
    }
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  /// Encrypts a plaintext string using AES-256 (CBC mode) with PBKDF2 derived key.
  /// Prepends a random 16-byte IV to the ciphertext.
  String encrypt(String plaintext, String password, String salt) {
    final key = deriveKey(password, salt);
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    final payload = '${AppConstants.encryptionHeader}$plaintext';
    final encrypted = encrypter.encrypt(payload, iv: iv);
    
    final combinedBytes = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combinedBytes.setRange(0, iv.bytes.length, iv.bytes);
    combinedBytes.setRange(iv.bytes.length, combinedBytes.length, encrypted.bytes);
    
    return base64Url.encode(combinedBytes);
  }

  /// Decrypts a base64url-encoded ciphertext. Tries PBKDF2 key first, falling back to legacy derivation.
  String decrypt(String ciphertextBase64, String password, String salt) {
    try {
      return _decryptWithKey(ciphertextBase64, deriveKey(password, salt));
    } catch (e) {
      AppLogger.w('PBKDF2 decryption failed, attempting legacy key derivation', tag: 'EncryptionService');
      try {
        return _decryptWithKey(ciphertextBase64, deriveLegacyKey(password, salt));
      } catch (legacyErr) {
        AppLogger.e('Decryption failed for both PBKDF2 and legacy keys', error: legacyErr, tag: 'EncryptionService');
        throw Exception('Decryption failed: invalid credentials or corrupted data.');
      }
    }
  }

  String _decryptWithKey(String ciphertextBase64, enc.Key key) {
    final combinedBytes = base64Url.decode(ciphertextBase64.trim());
    if (combinedBytes.length < 16) {
      throw Exception('Ciphertext too short');
    }
    
    final ivBytes = combinedBytes.sublist(0, 16);
    final encryptedBytes = combinedBytes.sublist(16);
    
    final iv = enc.IV(ivBytes);
    final encrypted = enc.Encrypted(encryptedBytes);
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    
    if (!decrypted.startsWith(AppConstants.encryptionHeader)) {
      throw Exception('Invalid magic header');
    }
    
    return decrypted.substring(AppConstants.encryptionHeader.length);
  }
}
