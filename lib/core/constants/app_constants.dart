class AppConstants {
  static const String encryptionHeader = 'MM_ENC:';
  static const String transferNotePrefix = 'Transfer to target account ID: ';
  static const String creditCardPaymentNotePrefix = 'Credit Card payment to account ID: ';
  
  static const String defaultCurrency = 'USD';
  static const String defaultTheme = 'dark';
  static const String defaultReminderTime = '20:00';
  
  // Storage keys for FlutterSecureStorage
  static const String securePinSaltKey = 'user_pin_salt';
  static const String secureSyncPasswordKey = 'sync_password';
  static const String secureSyncSaltKey = 'sync_salt';
  static const String secureSyncRoomCodeKey = 'sync_room_code';
  
  // Key derivation & encryption settings
  static const int pbkdf2Iterations = 100000;
  static const int pbkdf2KeyLength = 32; // 256 bits
  
  // Sync server defaults
  static const int syncRateLimitWindowMs = 60000; // 1 minute
  static const int syncRateLimitMaxRequests = 30;
}
