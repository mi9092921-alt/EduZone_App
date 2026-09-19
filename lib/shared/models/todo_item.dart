import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo_item.freezed.dart';
part 'todo_item.g.dart';

@freezed
abstract class TodoItem with _$TodoItem {
  const factory TodoItem({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String title,
    @JsonKey(name: 'due_at') DateTime? dueAt,
    @JsonKey(name: 'is_completed') @Default(false) bool isCompleted,
    @Default(0) int priority,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'deleted_at') DateTime? deletedAt,
  }) = _TodoItem;

  factory TodoItem.fromJson(Map<String, dynamic> json) =>
      _$TodoItemFromJson(json);

  /// Factory for skeleton dummy data.
  ///
  /// [dueAt] must be a fixed future date (not null): the home preview tile
  /// renders the formatted due date even while shimmering, and a null date
  /// here previously forced the tile to fall back to a hardcoded English
  /// 'Loading Date...' placeholder. A real (future) date renders a genuine
  /// formatted label under the shimmer instead, and being far in the future
  /// keeps the skeleton permanently non-overdue.
  factory TodoItem.skeleton() => TodoItem(
        id: 'skeleton',
        userId: 'skeleton',
        tenantId: 'skeleton',
        title: 'Loading Task...', // check-ignore
        dueAt: DateTime(2030),
      );
}
