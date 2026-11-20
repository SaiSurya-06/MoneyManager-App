import '../core/utils/money.dart';

class TransactionTemplate {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'income', 'expense', 'transfer'
  final int categoryId;
  final int accountId;

  TransactionTemplate({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
  });

  int get amountMinorUnits => Money.fromMajorUnits(amount).minorUnits;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'amount_minor': amountMinorUnits,
      'type': type,
      'category_id': categoryId,
      'account_id': accountId,
    };
  }

  factory TransactionTemplate.fromMap(Map<String, dynamic> map) {
    double amt;
    if (map['amount_minor'] != null) {
      amt = Money.fromMinorUnits(map['amount_minor'] as int).toMajorUnits();
    } else {
      amt = Money.fromMajorUnits((map['amount'] as num).toDouble()).toMajorUnits();
    }
    return TransactionTemplate(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: amt,
      type: map['type'] as String,
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int,
    );
  }

  TransactionTemplate copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    int? categoryId,
    int? accountId,
  }) {
    return TransactionTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
    );
  }
}
