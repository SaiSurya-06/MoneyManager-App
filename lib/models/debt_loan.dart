import 'dart:math';
import '../core/utils/money.dart';

class DebtLoan {
  final int? id;
  final String name;
  final String type; // 'loan', 'credit_card'
  final double balance;
  final double originalAmount;
  final double interestRate; // Annual interest rate in percent (e.g. 5.5) - NOT monetary
  final double monthlyPayment;
  final DateTime startDate;
  final DateTime createdAt;

  DebtLoan({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.originalAmount,
    required this.interestRate,
    required this.monthlyPayment,
    required this.startDate,
    required this.createdAt,
  });

  int get balanceMinorUnits => Money.fromMajorUnits(balance).minorUnits;
  int get originalAmountMinorUnits => Money.fromMajorUnits(originalAmount).minorUnits;
  int get monthlyPaymentMinorUnits => Money.fromMajorUnits(monthlyPayment).minorUnits;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'balance_minor': balanceMinorUnits,
      'original_amount': originalAmount,
      'original_amount_minor': originalAmountMinorUnits,
      'interest_rate': interestRate,
      'monthly_payment': monthlyPayment,
      'monthly_payment_minor': monthlyPaymentMinorUnits,
      'start_date': startDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DebtLoan.fromMap(Map<String, dynamic> map) {
    double bal;
    double orig;
    double payment;

    if (map['balance_minor'] != null) {
      bal = Money.fromMinorUnits(map['balance_minor'] as int).toMajorUnits();
    } else {
      bal = Money.fromMajorUnits((map['balance'] as num).toDouble()).toMajorUnits();
    }

    if (map['original_amount_minor'] != null) {
      orig = Money.fromMinorUnits(map['original_amount_minor'] as int).toMajorUnits();
    } else {
      orig = Money.fromMajorUnits((map['original_amount'] as num).toDouble()).toMajorUnits();
    }

    if (map['monthly_payment_minor'] != null) {
      payment = Money.fromMinorUnits(map['monthly_payment_minor'] as int).toMajorUnits();
    } else {
      payment = Money.fromMajorUnits((map['monthly_payment'] as num).toDouble()).toMajorUnits();
    }

    return DebtLoan(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: bal,
      originalAmount: orig,
      interestRate: (map['interest_rate'] as num).toDouble(),
      monthlyPayment: payment,
      startDate: DateTime.parse(map['start_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  DebtLoan copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    double? originalAmount,
    double? interestRate,
    double? monthlyPayment,
    DateTime? startDate,
    DateTime? createdAt,
  }) {
    return DebtLoan(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      originalAmount: originalAmount ?? this.originalAmount,
      interestRate: interestRate ?? this.interestRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Calculates the estimated number of months to pay off the debt.
  /// Returns -1 if it will never be paid off with the current monthly payment.
  int get monthsToPayoff {
    if (balance <= 0) return 0;
    if (monthlyPayment <= 0) return -1;

    if (interestRate <= 0) {
      return (balance / monthlyPayment).ceil();
    }

    final double monthlyRate = (interestRate / 100) / 12;

    // If interest accrued is higher than the payment, it never gets paid off
    if (balance * monthlyRate >= monthlyPayment) {
      return -1;
    }

    try {
      final double valuation = 1 - (monthlyRate * balance) / monthlyPayment;
      final double months = -log(valuation) / log(1 + monthlyRate);
      return months.ceil();
    } catch (_) {
      return -1;
    }
  }

  /// Calculates total interest paid over the payoff timeline
  double get totalInterestPaid {
    final int months = monthsToPayoff;
    if (months <= 0) return 0.0;
    return (monthlyPayment * months) - balance;
  }
}
