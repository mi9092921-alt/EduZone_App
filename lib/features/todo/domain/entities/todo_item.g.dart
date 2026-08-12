// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TodoItem _$TodoItemFromJson(Map<String, dynamic> json) => _TodoItem(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  tenantId: json['tenant_id'] as String,
  title: json['title'] as String,
  dueAt: json['due_at'] == null
      ? null
      : DateTime.parse(json['due_at'] as String),
  isCompleted: json['is_completed'] as bool? ?? false,
  priority: (json['priority'] as num?)?.toInt() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  deletedAt: json['deleted_at'] == null
      ? null
      : DateTime.parse(json['deleted_at'] as String),
);

Map<String, dynamic> _$TodoItemToJson(_TodoItem instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'tenant_id': instance.tenantId,
  'title': instance.title,
  'due_at': instance.dueAt?.toIso8601String(),
  'is_completed': instance.isCompleted,
  'priority': instance.priority,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'deleted_at': instance.deletedAt?.toIso8601String(),
};
