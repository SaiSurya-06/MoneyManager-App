import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/utils/money.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

@freezed
class Budget with _$Budget {
  const Budget._();

  const factory Budget({
    int? id,
    @JsonKey(name: 'category_id') required int categoryId,
    required String month,
    @JsonKey(name: 'limit_amount') required double limitAmount,
    @Default('monthly') String recurrence,
    @JsonKey(name: 'group_name') String? groupName,
  }) = _Budget;

  int get limitAmountMinorUnits => Money.fromMajorUnits(limitAmount).minorUnits;

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);

  Map<String, dynamic> toMap() {
    final map = toJson();
    map['limit_amount_minor'] = limitAmountMinorUnits;
    return map;
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    final adjustedMap = Map<String, dynamic>.from(map);
    if (map['limit_amount_minor'] != null) {
      adjustedMap['limit_amount'] = Money.fromMinorUnits(map['limit_amount_minor'] as int).toMajorUnits();
    } else {
      adjustedMap['limit_amount'] = Money.fromMajorUnits((map['limit_amount'] as num).toDouble()).toMajorUnits();
    }
    return Budget.fromJson(adjustedMap);
  }
}
