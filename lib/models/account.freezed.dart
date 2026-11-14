// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Account _$AccountFromJson(Map<String, dynamic> json) {
  return _Account.fromJson(json);
}

/// @nodoc
mixin _$Account {
  int? get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  double get balance => throw _privateConstructorUsedError;
  String get icon => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_shared')
  bool get isShared => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'limit_amount')
  double? get limitAmount => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_archived')
  bool get isArchived => throw _privateConstructorUsedError;
  @JsonKey(name: 'archived_at')
  DateTime? get archivedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'billing_cycle_start_day')
  int? get billingCycleStartDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'statement_due_day')
  int? get statementDueDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'minimum_due')
  double? get minimumDue => throw _privateConstructorUsedError;

  /// Serializes this Account to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AccountCopyWith<Account> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AccountCopyWith<$Res> {
  factory $AccountCopyWith(Account value, $Res Function(Account) then) =
      _$AccountCopyWithImpl<$Res, Account>;
  @useResult
  $Res call(
      {int? id,
      String name,
      String type,
      double balance,
      String icon,
      String color,
      @JsonKey(name: 'is_shared') bool isShared,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'limit_amount') double? limitAmount,
      @JsonKey(name: 'is_archived') bool isArchived,
      @JsonKey(name: 'archived_at') DateTime? archivedAt,
      @JsonKey(name: 'billing_cycle_start_day') int? billingCycleStartDay,
      @JsonKey(name: 'statement_due_day') int? statementDueDay,
      @JsonKey(name: 'minimum_due') double? minimumDue});
}

/// @nodoc
class _$AccountCopyWithImpl<$Res, $Val extends Account>
    implements $AccountCopyWith<$Res> {
  _$AccountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? type = null,
    Object? balance = null,
    Object? icon = null,
    Object? color = null,
    Object? isShared = null,
    Object? createdAt = null,
    Object? limitAmount = freezed,
    Object? isArchived = null,
    Object? archivedAt = freezed,
    Object? billingCycleStartDay = freezed,
    Object? statementDueDay = freezed,
    Object? minimumDue = freezed,
  }) {
    return _then(_value.copyWith(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      isShared: null == isShared
          ? _value.isShared
          : isShared // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      limitAmount: freezed == limitAmount
          ? _value.limitAmount
          : limitAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      archivedAt: freezed == archivedAt
          ? _value.archivedAt
          : archivedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      billingCycleStartDay: freezed == billingCycleStartDay
          ? _value.billingCycleStartDay
          : billingCycleStartDay // ignore: cast_nullable_to_non_nullable
              as int?,
      statementDueDay: freezed == statementDueDay
          ? _value.statementDueDay
          : statementDueDay // ignore: cast_nullable_to_non_nullable
              as int?,
      minimumDue: freezed == minimumDue
          ? _value.minimumDue
          : minimumDue // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AccountImplCopyWith<$Res> implements $AccountCopyWith<$Res> {
  factory _$$AccountImplCopyWith(
          _$AccountImpl value, $Res Function(_$AccountImpl) then) =
      __$$AccountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int? id,
      String name,
      String type,
      double balance,
      String icon,
      String color,
      @JsonKey(name: 'is_shared') bool isShared,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'limit_amount') double? limitAmount,
      @JsonKey(name: 'is_archived') bool isArchived,
      @JsonKey(name: 'archived_at') DateTime? archivedAt,
      @JsonKey(name: 'billing_cycle_start_day') int? billingCycleStartDay,
      @JsonKey(name: 'statement_due_day') int? statementDueDay,
      @JsonKey(name: 'minimum_due') double? minimumDue});
}

/// @nodoc
class __$$AccountImplCopyWithImpl<$Res>
    extends _$AccountCopyWithImpl<$Res, _$AccountImpl>
    implements _$$AccountImplCopyWith<$Res> {
  __$$AccountImplCopyWithImpl(
      _$AccountImpl _value, $Res Function(_$AccountImpl) _then)
      : super(_value, _then);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = freezed,
    Object? name = null,
    Object? type = null,
    Object? balance = null,
    Object? icon = null,
    Object? color = null,
    Object? isShared = null,
    Object? createdAt = null,
    Object? limitAmount = freezed,
    Object? isArchived = null,
    Object? archivedAt = freezed,
    Object? billingCycleStartDay = freezed,
    Object? statementDueDay = freezed,
    Object? minimumDue = freezed,
  }) {
    return _then(_$AccountImpl(
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      icon: null == icon
          ? _value.icon
          : icon // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      isShared: null == isShared
          ? _value.isShared
          : isShared // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      limitAmount: freezed == limitAmount
          ? _value.limitAmount
          : limitAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      isArchived: null == isArchived
          ? _value.isArchived
          : isArchived // ignore: cast_nullable_to_non_nullable
              as bool,
      archivedAt: freezed == archivedAt
          ? _value.archivedAt
          : archivedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      billingCycleStartDay: freezed == billingCycleStartDay
          ? _value.billingCycleStartDay
          : billingCycleStartDay // ignore: cast_nullable_to_non_nullable
              as int?,
      statementDueDay: freezed == statementDueDay
          ? _value.statementDueDay
          : statementDueDay // ignore: cast_nullable_to_non_nullable
              as int?,
      minimumDue: freezed == minimumDue
          ? _value.minimumDue
          : minimumDue // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AccountImpl extends _Account {
  const _$AccountImpl(
      {this.id,
      required this.name,
      required this.type,
      required this.balance,
      required this.icon,
      required this.color,
      @JsonKey(name: 'is_shared') required this.isShared,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'limit_amount') this.limitAmount,
      @JsonKey(name: 'is_archived') this.isArchived = false,
      @JsonKey(name: 'archived_at') this.archivedAt,
      @JsonKey(name: 'billing_cycle_start_day') this.billingCycleStartDay,
      @JsonKey(name: 'statement_due_day') this.statementDueDay,
      @JsonKey(name: 'minimum_due') this.minimumDue})
      : super._();

  factory _$AccountImpl.fromJson(Map<String, dynamic> json) =>
      _$$AccountImplFromJson(json);

  @override
  final int? id;
  @override
  final String name;
  @override
  final String type;
  @override
  final double balance;
  @override
  final String icon;
  @override
  final String color;
  @override
  @JsonKey(name: 'is_shared')
  final bool isShared;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'limit_amount')
  final double? limitAmount;
  @override
  @JsonKey(name: 'is_archived')
  final bool isArchived;
  @override
  @JsonKey(name: 'archived_at')
  final DateTime? archivedAt;
  @override
  @JsonKey(name: 'billing_cycle_start_day')
  final int? billingCycleStartDay;
  @override
  @JsonKey(name: 'statement_due_day')
  final int? statementDueDay;
  @override
  @JsonKey(name: 'minimum_due')
  final double? minimumDue;

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: $type, balance: $balance, icon: $icon, color: $color, isShared: $isShared, createdAt: $createdAt, limitAmount: $limitAmount, isArchived: $isArchived, archivedAt: $archivedAt, billingCycleStartDay: $billingCycleStartDay, statementDueDay: $statementDueDay, minimumDue: $minimumDue)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AccountImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.icon, icon) || other.icon == icon) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.isShared, isShared) ||
                other.isShared == isShared) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.limitAmount, limitAmount) ||
                other.limitAmount == limitAmount) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.archivedAt, archivedAt) ||
                other.archivedAt == archivedAt) &&
            (identical(other.billingCycleStartDay, billingCycleStartDay) ||
                other.billingCycleStartDay == billingCycleStartDay) &&
            (identical(other.statementDueDay, statementDueDay) ||
                other.statementDueDay == statementDueDay) &&
            (identical(other.minimumDue, minimumDue) ||
                other.minimumDue == minimumDue));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      type,
      balance,
      icon,
      color,
      isShared,
      createdAt,
      limitAmount,
      isArchived,
      archivedAt,
      billingCycleStartDay,
      statementDueDay,
      minimumDue);

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      __$$AccountImplCopyWithImpl<_$AccountImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AccountImplToJson(
      this,
    );
  }
}

abstract class _Account extends Account {
  const factory _Account(
          {final int? id,
          required final String name,
          required final String type,
          required final double balance,
          required final String icon,
          required final String color,
          @JsonKey(name: 'is_shared') required final bool isShared,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'limit_amount') final double? limitAmount,
          @JsonKey(name: 'is_archived') final bool isArchived,
          @JsonKey(name: 'archived_at') final DateTime? archivedAt,
          @JsonKey(name: 'billing_cycle_start_day')
          final int? billingCycleStartDay,
          @JsonKey(name: 'statement_due_day') final int? statementDueDay,
          @JsonKey(name: 'minimum_due') final double? minimumDue}) =
      _$AccountImpl;
  const _Account._() : super._();

  factory _Account.fromJson(Map<String, dynamic> json) =
      _$AccountImpl.fromJson;

  @override
  int? get id;
  @override
  String get name;
  @override
  String get type;
  @override
  double get balance;
  @override
  String get icon;
  @override
  String get color;
  @override
  @JsonKey(name: 'is_shared')
  bool get isShared;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'limit_amount')
  double? get limitAmount;
  @override
  @JsonKey(name: 'is_archived')
  bool get isArchived;
  @override
  @JsonKey(name: 'archived_at')
  DateTime? get archivedAt;
  @override
  @JsonKey(name: 'billing_cycle_start_day')
  int? get billingCycleStartDay;
  @override
  @JsonKey(name: 'statement_due_day')
  int? get statementDueDay;
  @override
  @JsonKey(name: 'minimum_due')
  double? get minimumDue;

  /// Create a copy of Account
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AccountImplCopyWith<_$AccountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
