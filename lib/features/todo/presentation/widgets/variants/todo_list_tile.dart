import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../domain/entities/todo_item.dart';
import '../../extensions/todo_ui_extension.dart';
import '../components/todo_card_base.dart';
import '../components/todo_checkbox.dart';
import '../components/todo_content.dart';
import '../components/todo_meta_info.dart';
import '../components/todo_priority_indicator.dart';
import '../components/todo_swipe_background.dart';
import '../core/todo_ui_mapper.dart';

class TodoListTile extends StatelessWidget {
  final TodoItem todo;
  final ValueChanged<bool?> onStatusChanged;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const TodoListTile({
    required this.todo,
    required this.onStatusChanged,
    required this.onDelete,
    this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final isOverdue = todo.isOverdue(now);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      child: Dismissible(
        key: ValueKey('dismiss_${todo.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit?.call();
            return false;
          }
          return await _showDeleteConfirmation(context, l10n);
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            HapticFeedback.mediumImpact();
            onDelete();
          }
        },
        background: TodoSwipeBackground.edit(label: l10n.editButton),
        secondaryBackground: TodoSwipeBackground.delete(
          label: l10n.deleteButton,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TodoCardBase(
                  onTap: onEdit,
                  isCompleted: todo.isCompleted,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TodoCheckbox(
                        value: todo.isCompleted,
                        onChanged: onStatusChanged,
                        label: todo.title,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TodoContent(
                              title: todo.title,
                              isCompleted: todo.isCompleted,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (todo.dueAt != null)
                                  TodoMetaInfo(
                                    dateText: TodoUiMapper.getFormattedDate(
                                      context: context,
                                      todo: todo,
                                    ),
                                    isOverdue: isOverdue,
                                  )
                                else
                                  const SizedBox.shrink(),
                                TodoPriorityIndicator(
                                  priority: todo.priority,
                                  style: TodoPriorityStyle.pill,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.confirmDeleteMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
  }
}
