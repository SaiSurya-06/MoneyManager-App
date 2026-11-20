import '../core/utils/money.dart';

class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String color; // Hex color string
  final String icon; // Icon key mapping to IconData
  final DateTime createdAt;

  SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  int get targetAmountMinorUnits => Money.fromMajorUnits(targetAmount).minorUnits;
  int get currentAmountMinorUnits => Money.fromMajorUnits(currentAmount).minorUnits;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'target_amount_minor': targetAmountMinorUnits,
      'current_amount': currentAmount,
      'current_amount_minor': currentAmountMinorUnits,
      'target_date': targetDate?.toIso8601String(),
      'color': color,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    double target;
    double current;
    if (map['target_amount_minor'] != null) {
      target = Money.fromMinorUnits(map['target_amount_minor'] as int).toMajorUnits();
    } else {
      target = Money.fromMajorUnits((map['target_amount'] as num).toDouble()).toMajorUnits();
    }

    if (map['current_amount_minor'] != null) {
      current = Money.fromMinorUnits(map['current_amount_minor'] as int).toMajorUnits();
    } else {
      current = Money.fromMajorUnits((map['current_amount'] as num).toDouble()).toMajorUnits();
    }

    return SavingsGoal(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetAmount: target,
      currentAmount: current,
      targetDate: map['target_date'] != null ? DateTime.parse(map['target_date'] as String) : null,
      color: map['color'] as String,
      icon: map['icon'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SavingsGoal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
