import 'package:intl/intl.dart';
import 'money.dart';

class CurrencyFormatter {
  /// Rounds amount according to currency exponent.
  static double roundAmount(double amount, [String currencyCode = 'INR']) {
    return Money.fromMajorUnits(amount, currencyCode).toMajorUnits();
  }

  /// Formats major unit amount with the correct symbol and decimal digits according to currency rules.
  static String format(double amount, String currencyCode, {String? locale}) {
    return Money.fromMajorUnits(amount, currencyCode).format(locale: locale);
  }

  /// Formats exact integer minor units directly.
  static String formatMinorUnits(int minorUnits, String currencyCode, {String? locale}) {
    return Money.fromMinorUnits(minorUnits, currencyCode).format(locale: locale);
  }

  /// Returns the currency symbol for the given currency code.
  static String getSymbol(String currencyCode) {
    return Money.getSymbol(currencyCode);
  }
}
