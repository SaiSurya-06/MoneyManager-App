import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/utils/money.dart';
import 'package:money_manager/core/utils/currency_formatter.dart';
import 'package:money_manager/models/account.dart';
import 'package:money_manager/models/transaction.dart';
import 'package:money_manager/models/budget.dart';
import 'package:money_manager/models/debt_loan.dart';
import 'package:money_manager/models/savings_goal.dart';
import 'package:money_manager/models/transaction_template.dart';

void main() {
  group('F01: Financial Amount Precision - Money Unit Tests', () {
    test('₹100.10 + ₹200.20 + ₹300.30 equals ₹600.60 exactly without floating point drift', () {
      final m1 = Money.fromMajorUnits(100.10, 'INR');
      final m2 = Money.fromMajorUnits(200.20, 'INR');
      final m3 = Money.fromMajorUnits(300.30, 'INR');

      expect(m1.minorUnits, equals(10010));
      expect(m2.minorUnits, equals(20020));
      expect(m3.minorUnits, equals(30030));

      final sum = m1 + m2 + m3;
      expect(sum.minorUnits, equals(60060));
      expect(sum.toMajorUnits(), equals(600.60));
    });

    test('Multiple decimal additions and subtractions maintain exact minor units', () {
      var balance = Money.fromMajorUnits(1000.00, 'USD');
      // Consecutive deductions that traditionally cause float inaccuracies
      balance = balance - Money.fromMajorUnits(0.10, 'USD');
      balance = balance - Money.fromMajorUnits(0.20, 'USD');
      balance = balance - Money.fromMajorUnits(0.30, 'USD');

      expect(balance.minorUnits, equals(99940));
      expect(balance.toMajorUnits(), equals(999.40));
    });

    test('Zero-decimal currency support (e.g. JPY)', () {
      final jpy = Money.fromMajorUnits(5000, 'JPY');
      expect(jpy.minorUnits, equals(5000));
      expect(jpy.toMajorUnits(), equals(5000.0));
      expect(Money.getExponent('JPY'), equals(0));
    });

    test('Three-decimal currency support (e.g. KWD)', () {
      final kwd = Money.fromMajorUnits(12.345, 'KWD');
      expect(kwd.minorUnits, equals(12345));
      expect(kwd.toMajorUnits(), equals(12.345));
      expect(Money.getExponent('KWD'), equals(3));
    });

    test('Martin Fowler Allocation preserves every single minor unit without loss', () {
      final total = Money.fromMinorUnits(100, 'INR'); // ₹1.00 = 100 paise
      // Allocate into 3 equal parts (100 / 3 = 33.333...)
      final parts = total.split(3);

      expect(parts.length, equals(3));
      expect(parts[0].minorUnits, equals(34)); // remainder distributed to first part
      expect(parts[1].minorUnits, equals(33));
      expect(parts[2].minorUnits, equals(33));

      final allocatedSum = parts[0] + parts[1] + parts[2];
      expect(allocatedSum.minorUnits, equals(100)); // Exactly 100 paise preserved!
    });

    test('Budget percentage calculation with deterministic rounding', () {
      final budget = Money.fromMajorUnits(15000.00, 'INR');
      final allowance = budget.percentage(33.33);
      // 1500000 paise * 0.3333 = 499950 paise = ₹4,999.50
      expect(allowance.minorUnits, equals(499950));
      expect(allowance.toMajorUnits(), equals(4999.50));
    });

    test('Negative amounts and Credit Card liability representation', () {
      final ccLiability = Money.fromMajorUnits(-4500.75, 'INR');
      expect(ccLiability.isNegative, isTrue);
      expect(ccLiability.minorUnits, equals(-450075));
      expect(ccLiability.abs().minorUnits, equals(450075));
    });

    test('Explicit exchange rate conversion', () {
      final inr = Money.fromMajorUnits(8300.00, 'INR');
      // Convert INR to USD at rate of 1 USD = 83 INR (0.01204819277)
      final usd = inr.convertTo('USD', 1 / 83.0);
      expect(usd.currency, equals('USD'));
      expect(usd.toMajorUnits(), equals(100.00));
      expect(usd.minorUnits, equals(10000));
    });

    test('Currency mismatch throws ArgumentError without explicit conversion', () {
      final inr = Money.fromMajorUnits(100.00, 'INR');
      final usd = Money.fromMajorUnits(100.00, 'USD');
      expect(() => inr + usd, throwsArgumentError);
    });

    test('Account model balance and limitAmount minor unit properties', () {
      final acc = Account(
        name: 'HDFC Bank',
        type: 'Bank',
        balance: 25400.55,
        icon: 'account_balance',
        color: '#1E88E5',
        isShared: true,
        createdAt: DateTime(2026, 1, 1),
        limitAmount: 50000.00,
      );

      expect(acc.balanceMinorUnits, equals(2540055));
      expect(acc.limitAmountMinorUnits, equals(5000000));

      final map = acc.toMap();
      expect(map['balance_minor'], equals(2540055));
      expect(map['limit_amount_minor'], equals(5000000));

      // Deserialization from minor units
      final fromDb = Account.fromMap({
        'name': 'HDFC Bank',
        'type': 'Bank',
        'balance': 25400.55,
        'balance_minor': 2540055,
        'icon': 'account_balance',
        'color': '#1E88E5',
        'is_shared': 1,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'limit_amount_minor': 5000000,
      });

      expect(fromDb.balance, equals(25400.55));
      expect(fromDb.balanceMinorUnits, equals(2540055));
      expect(fromDb.limitAmount, equals(50000.00));
    });

    test('Transaction model amount minor unit serialization and deserialization', () {
      final tx = Transaction(
        accountId: 1,
        categoryId: 2,
        title: 'Groceries',
        amount: 1250.75,
        type: 'expense',
        date: DateTime(2026, 10, 15),
        isPrivate: false,
        createdAt: DateTime(2026, 10, 15),
      );

      expect(tx.amountMinorUnits, equals(125075));
      final map = tx.toMap();
      expect(map['amount_minor'], equals(125075));

      final restored = Transaction.fromMap(map);
      expect(restored.amount, equals(1250.75));
      expect(restored.amountMinorUnits, equals(125075));
    });
  });
}
