import 'dart:math' as math;
import 'package:intl/intl.dart';

/// Centralized, production-grade Money & Currency utility for Money Manager.
///
/// Stores financial amounts as exact integer minor units (e.g. paise for INR, cents for USD).
/// Provides deterministic arithmetic, rounding, allocation, and locale-aware formatting.
/// Prevents floating-point precision errors across the entire application.
class Money implements Comparable<Money> {
  /// The exact financial amount in minor units (e.g. 125075 for ₹1,250.75).
  final int minorUnits;

  /// ISO 4217 Currency Code (e.g. 'INR', 'USD', 'EUR', 'JPY', 'KWD').
  final String currency;

  const Money._(this.minorUnits, this.currency);

  /// Returns the minor unit exponent (number of decimal places) for [currency].
  ///
  /// - Exponent 0: JPY, KRW, VND, CLP, PYG, RWF, UGX, BIF, DJF, GNF, KMF, XOF, XAF, XPF
  /// - Exponent 3: BHD, KWD, OMR, JOD, TND, IQD, LYD
  /// - Exponent 2: INR, USD, EUR, GBP, CAD, AUD, CHF, CNY, SGD, and all other standard currencies.
  static int getExponent(String currency) {
    switch (currency.toUpperCase()) {
      case 'JPY':
      case 'KRW':
      case 'VND':
      case 'CLP':
      case 'PYG':
      case 'RWF':
      case 'UGX':
      case 'BIF':
      case 'DJF':
      case 'GNF':
      case 'KMF':
      case 'XOF':
      case 'XAF':
      case 'XPF':
        return 0;
      case 'BHD':
      case 'KWD':
      case 'OMR':
      case 'JOD':
      case 'TND':
      case 'IQD':
      case 'LYD':
        return 3;
      default:
        return 2;
    }
  }

  /// Scale factor for converting between major and minor units.
  static int factorFor(String currency) {
    final exp = getExponent(currency);
    if (exp == 0) return 1;
    if (exp == 1) return 10;
    if (exp == 3) return 1000;
    return 100;
  }

  /// Creates a [Money] instance from exact integer minor units.
  factory Money.fromMinorUnits(int minorUnits, [String currency = 'INR']) {
    return Money._(minorUnits, currency.toUpperCase());
  }

  /// Creates a [Money] instance from a major unit number (e.g. 1250.75).
  ///
  /// Uses deterministic half-up rounding to prevent floating-point representation drift.
  factory Money.fromMajorUnits(num majorUnits, [String currency = 'INR']) {
    final factor = factorFor(currency);
    final sign = majorUnits.isNegative ? -1 : 1;
    final absVal = majorUnits.abs();
    // Deterministic half-up rounding
    final minor = ((absVal * factor) + 0.5000000001).floor() * sign;
    return Money._(minor, currency.toUpperCase());
  }

  /// Zero money in the given [currency].
  factory Money.zero([String currency = 'INR']) {
    return Money._(0, currency.toUpperCase());
  }

  /// Parses a string into a [Money] object safely.
  factory Money.parse(String text, [String currency = 'INR']) {
    final cleaned = text.trim().replaceAll(RegExp(r'[^0-9.-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
      return Money.zero(currency);
    }
    final val = double.tryParse(cleaned) ?? 0.0;
    return Money.fromMajorUnits(val, currency);
  }

  /// Converts this [Money] to major units (e.g. 125075 paise -> 1250.75 rupees).
  double toMajorUnits() {
    final factor = factorFor(currency);
    return minorUnits / factor;
  }

  /// Formats the money into a localized string with proper currency symbol and decimals.
  String format({String? locale}) {
    final exp = getExponent(currency);
    final symbol = getSymbol(currency);
    final format = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: exp,
    );
    return format.format(toMajorUnits());
  }

  /// Returns the currency symbol for the given currency code.
  static String getSymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'INR':
        return '₹';
      case 'JPY':
        return '¥';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'KWD':
        return 'KD ';
      default:
        return '$currencyCode ';
    }
  }

  // ── Exact Arithmetic ───────────────────────────────────────────────────────

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: cannot perform arithmetic between $currency and ${other.currency}. '
        'Perform an explicit conversion first via convertTo().',
      );
    }
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits - other.minorUnits, currency);
  }

  /// Multiplies this money by a scalar [multiplier] with exact deterministic rounding.
  Money operator *(num multiplier) {
    final sign = (minorUnits < 0) ^ (multiplier < 0) ? -1 : 1;
    final absMinor = minorUnits.abs();
    final absMultiplier = multiplier.abs();
    final result = ((absMinor * absMultiplier) + 0.5000000001).floor() * sign;
    return Money._(result, currency);
  }

  /// Divides this money by a scalar [divisor] with exact deterministic rounding.
  Money operator /(num divisor) {
    if (divisor == 0) {
      throw IntegerDivisionByZeroException();
    }
    final sign = (minorUnits < 0) ^ (divisor < 0) ? -1 : 1;
    final absMinor = minorUnits.abs();
    final absDivisor = divisor.abs();
    final result = ((absMinor / absDivisor) + 0.5000000001).floor() * sign;
    return Money._(result, currency);
  }

  /// Calculates a percentage of this money (e.g. `money.percentage(18.0)` for 18% tax).
  Money percentage(num percent) {
    return this * (percent / 100.0);
  }

  /// Martin Fowler Money Allocation Pattern:
  ///
  /// Distributes this amount across [ratios] without losing even a single minor unit.
  /// Division remainders are distributed 1 minor unit at a time to the leading ratios.
  List<Money> allocate(List<int> ratios) {
    if (ratios.isEmpty) return [];
    final totalRatio = ratios.fold<int>(0, (sum, r) => sum + r);
    if (totalRatio <= 0) {
      throw ArgumentError('Sum of ratios must be greater than zero.');
    }

    int remainder = minorUnits;
    final results = <int>[];

    for (final ratio in ratios) {
      final share = (minorUnits * ratio) ~/ totalRatio;
      results.add(share);
      remainder -= share;
    }

    // Distribute remainder 1 minor unit at a time
    for (int i = 0; i < remainder; i++) {
      results[i % results.length] += 1;
    }

    return results.map((m) => Money._(m, currency)).toList();
  }

  /// Distributes this amount evenly into [parts] parts, allocating remainders deterministically.
  List<Money> split(int parts) {
    if (parts <= 0) throw ArgumentError('Parts must be greater than zero.');
    return allocate(List<int>.filled(parts, 1));
  }

  /// Converts this [Money] to [targetCurrency] using an explicit [exchangeRate].
  Money convertTo(String targetCurrency, double exchangeRate) {
    if (exchangeRate <= 0) {
      throw ArgumentError('Exchange rate must be positive.');
    }
    final convertedMajor = toMajorUnits() * exchangeRate;
    return Money.fromMajorUnits(convertedMajor, targetCurrency);
  }

  Money abs() => Money._(minorUnits.abs(), currency);

  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;
  bool get isZero => minorUnits == 0;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Money && other.minorUnits == minorUnits && other.currency == currency;
  }

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => format();
}
