import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../shared/components/todo/todo_card_base.dart';
import '../../../../../shared/components/todo/todo_checkbox.dart';
import '../../../../../shared/components/todo/todo_priority_indicator.dart';
import '../../../../../shared/components/todo/todo_ui_extension.dart';
import '../../../../../shared/components/todo/todo_ui_mapper.dart';
import '../../../../../shared/models/todo_item.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';
import '../components/todo_content.dart';
import '../components/todo_meta_info.dart';
import '../components/todo_swipe_background.dart';

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
        vertical: AppSpacing.xs2,
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
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: l10n.confirmDeleteTitle,
        description: l10n.confirmDeleteMsg,
        confirmLabel: l10n.deleteButton,
        cancelLabel: l10n.cancel,
        isDangerous: true,
        // Cancel pops with null (ConfirmDialog default); the Dismissible
        // confirmDismiss caller only acts on `true`, so behavior is
        // identical to the previous pop(false).
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }
}
