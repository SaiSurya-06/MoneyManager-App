// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AccountImpl _$$AccountImplFromJson(Map<String, dynamic> json) =>
    _$AccountImpl(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      balance: (json['balance'] as num).toDouble(),
      icon: json['icon'] as String,
      color: json['color'] as String,
      isShared: json['is_shared'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      limitAmount: (json['limit_amount'] as num?)?.toDouble(),
      isArchived: json['is_archived'] as bool? ?? false,
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String),
      billingCycleStartDay:
          (json['billing_cycle_start_day'] as num?)?.toInt(),
      statementDueDay: (json['statement_due_day'] as num?)?.toInt(),
      minimumDue: (json['minimum_due'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$AccountImplToJson(_$AccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'balance': instance.balance,
      'icon': instance.icon,
      'color': instance.color,
      'is_shared': instance.isShared,
      'created_at': instance.createdAt.toIso8601String(),
      'limit_amount': instance.limitAmount,
      'is_archived': instance.isArchived,
      'archived_at': instance.archivedAt?.toIso8601String(),
      'billing_cycle_start_day': instance.billingCycleStartDay,
      'statement_due_day': instance.statementDueDay,
      'minimum_due': instance.minimumDue,
    };
