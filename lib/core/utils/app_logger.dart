import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static void log(String message, {LogLevel level = LogLevel.info, Object? error, StackTrace? stackTrace, String? tag}) {
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final timeStr = DateTime.now().toIso8601String();
    final logMessage = '[$timeStr] [${level.name.toUpperCase()}] $tagPrefix$message';

    if (kDebugMode) {
      debugPrint(logMessage);
      if (error != null) debugPrint('Error details: $error');
      if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
    }
  }

  static void d(String message, {String? tag}) => log(message, level: LogLevel.debug, tag: tag);
  static void i(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  static void w(String message, {Object? error, String? tag}) => log(message, level: LogLevel.warning, error: error, tag: tag);
  static void e(String message, {Object? error, StackTrace? stackTrace, String? tag}) => log(message, level: LogLevel.error, error: error, stackTrace: stackTrace, tag: tag);
}
