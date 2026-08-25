import 'package:app/design_system/design_system.dart';
import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/presentation/extensions/todo_ui_extension.dart';
import 'package:flutter_test/flutter_test.dart';

TodoItem _todo({
  DateTime? dueAt,
  bool isCompleted = false,
  int priority = 0,
}) {
  return TodoItem(
    id: 'todo-1',
    userId: 'user-1',
    tenantId: 'tenant-1',
    title: 'Test task',
    dueAt: dueAt,
    isCompleted: isCompleted,
    priority: priority,
  );
}

void main() {
  group('TodoUIX.isOverdue', () {
    final now = DateTime(2026, 8, 25, 20);

    test('a due date later today is not overdue', () {
      final todo = _todo(dueAt: DateTime(2026, 8, 25, 0, 1));

      expect(todo.isOverdue(now), isFalse);
    });

    test('a due date on the previous calendar day is overdue', () {
      final todo = _todo(dueAt: DateTime(2026, 8, 24, 23, 59));

      expect(todo.isOverdue(now), isTrue);
    });

    test('a completed todo is never overdue', () {
      final todo = _todo(
        dueAt: DateTime(2026, 8, 24),
        isCompleted: true,
      );

      expect(todo.isOverdue(now), isFalse);
    });
  });

  group('TodoUIX.priorityColor', () {
    test('returns correct semantic colors based on priority', () {
      final colors = DesignSystemColors.light();

      expect(
        _todo(priority: 2).priorityColor(colors),
        AppColors.error,
      );
      expect(
        _todo(priority: 1).priorityColor(colors),
        AppColors.warning,
      );
      expect(
        _todo().priorityColor(colors),
        AppColors.success,
      );
    });
  });
}
