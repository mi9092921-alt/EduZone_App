import 'package:app/design_system/design_system.dart';
import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:app/features/todo/presentation/extensions/todo_ui_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TodoUIX Extension Tests', () {
    final baseTodo = TodoItem(
      id: '1',
      userId: 'user_1',
      tenantId: 'tenant_1',
      title: 'Test Task',
      priority: 1,
      createdAt: DateTime.now(),
    );

    test(
      'isOverdue should return true if dueAt is before now and not completed',
      () {
        final now = DateTime(2026, 4, 14, 12);
        final todo = baseTodo.copyWith(dueAt: DateTime(2026, 4, 14, 11));
        expect(todo.isOverdue(now), isTrue);
      },
    );

    test('isOverdue should return false if dueAt is after now', () {
      final now = DateTime(2026, 4, 14, 12);
      final todo = baseTodo.copyWith(dueAt: DateTime(2026, 4, 14, 13));
      expect(todo.isOverdue(now), isFalse);
    });

    test('isOverdue should return false if completed regardless of date', () {
      final now = DateTime(2026, 4, 14, 12);
      final todo = baseTodo.copyWith(
        dueAt: DateTime(2026, 4, 14, 11),
        isCompleted: true,
      );
      expect(todo.isOverdue(now), isFalse);
    });

    test('priorityColor should return correct semantic colors', () {
      final colors = DesignSystemColors.light();

      expect(
        baseTodo.copyWith(priority: 2).priorityColor(colors),
        AppColors.error,
      );
      expect(
        baseTodo.copyWith(priority: 1).priorityColor(colors),
        AppColors.warning,
      );
      expect(
        baseTodo.copyWith(priority: 0).priorityColor(colors),
        AppColors.success,
      );
    });
  });
}
