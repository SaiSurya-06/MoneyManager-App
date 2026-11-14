import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/utils/money.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const Account._();

  const factory Account({
    int? id,
    required String name,
    required String type,
    required double balance,
    required String icon,
    required String color,
    @JsonKey(name: 'is_shared') required bool isShared,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'limit_amount') double? limitAmount,
    @JsonKey(name: 'is_archived') @Default(false) bool isArchived,
    @JsonKey(name: 'archived_at') DateTime? archivedAt,
    @JsonKey(name: 'billing_cycle_start_day') int? billingCycleStartDay,
    @JsonKey(name: 'statement_due_day') int? statementDueDay,
    @JsonKey(name: 'minimum_due') double? minimumDue,
  }) = _Account;

  int get balanceMinorUnits => Money.fromMajorUnits(balance).minorUnits;
  int? get limitAmountMinorUnits => limitAmount != null ? Money.fromMajorUnits(limitAmount!).minorUnits : null;
  int? get minimumDueMinorUnits => minimumDue != null ? Money.fromMajorUnits(minimumDue!).minorUnits : null;

  double get availableCredit => (limitAmount ?? 0.0) - pendingPayment;
  int get availableCreditMinorUnits => (limitAmountMinorUnits ?? 0) - pendingPaymentMinorUnits;

  double get pendingPayment => type == 'Credit Card' ? (balance < 0 ? -balance : 0.0) : 0.0;
  int get pendingPaymentMinorUnits => type == 'Credit Card' ? (balanceMinorUnits < 0 ? -balanceMinorUnits : 0) : 0;

  factory Account.fromJson(Map<String, dynamic> json) => _$AccountFromJson(json);

  Map<String, dynamic> toMap() {
    final map = toJson();
    map['is_shared'] = isShared ? 1 : 0;
    map['is_archived'] = isArchived ? 1 : 0;
    map['archived_at'] = archivedAt?.toIso8601String();
    map['balance_minor'] = balanceMinorUnits;
    if (limitAmount != null) {
      map['limit_amount_minor'] = limitAmountMinorUnits;
    }
    if (minimumDue != null) {
      map['minimum_due_minor'] = minimumDueMinorUnits;
    }
    return map;
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    final adjustedMap = Map<String, dynamic>.from(map);
    adjustedMap['is_shared'] = (map['is_shared'] as int) == 1;
    adjustedMap['is_archived'] = map['is_archived'] != null ? (map['is_archived'] as int) == 1 : false;
    if (map['archived_at'] != null) {
      adjustedMap['archived_at'] = map['archived_at'];
    }

    if (map['balance_minor'] != null) {
      adjustedMap['balance'] = Money.fromMinorUnits(map['balance_minor'] as int).toMajorUnits();
    } else {
      adjustedMap['balance'] = Money.fromMajorUnits((map['balance'] as num).toDouble()).toMajorUnits();
    }

    if (map['limit_amount_minor'] != null) {
      adjustedMap['limit_amount'] = Money.fromMinorUnits(map['limit_amount_minor'] as int).toMajorUnits();
    } else if (map['limit_amount'] != null) {
      adjustedMap['limit_amount'] = Money.fromMajorUnits((map['limit_amount'] as num).toDouble()).toMajorUnits();
    }

    if (map['minimum_due_minor'] != null) {
      adjustedMap['minimum_due'] = Money.fromMinorUnits(map['minimum_due_minor'] as int).toMajorUnits();
    } else if (map['minimum_due'] != null) {
      adjustedMap['minimum_due'] = Money.fromMajorUnits((map['minimum_due'] as num).toDouble()).toMajorUnits();
    }

    return Account.fromJson(adjustedMap);
  }
}
