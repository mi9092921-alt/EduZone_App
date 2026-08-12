import 'package:app/core/utils/text_direction_detector.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/todo_item.dart';
import '../../extensions/todo_ui_extension.dart';
import '../components/todo_card_base.dart';
import '../components/todo_checkbox.dart';
import '../components/todo_priority_indicator.dart';
import '../core/todo_ui_mapper.dart';

class TodoPreviewTile extends StatelessWidget {
  final TodoItem? todo;
  final bool isLoading;
  final VoidCallback? onToggle;

  const TodoPreviewTile({
    super.key,
    this.todo,
    this.isLoading = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppSkeleton(
        child: _buildMainContent(context, TodoItem.skeleton()),
      );
    }
    if (todo == null) return const SizedBox.shrink();

    return _buildMainContent(context, todo!);
  }

  Widget _buildMainContent(BuildContext context, TodoItem item) {
    final ds = AppColors.of(context);
    final dateStr = TodoUiMapper.getFormattedDate(context: context, todo: item);
    final ambientDirection = Directionality.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: TodoCardBase(
          isCompleted: item.isCompleted,
          onTap: isLoading ? null : onToggle,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TodoCheckbox(
                value: item.isCompleted,
                onChanged: isLoading ? (_) {} : (_) => onToggle?.call(),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      textDirection: TextDirectionDetector.detect(
                        item.title,
                        fallback: ambientDirection,
                      ),
                      textAlign: TextDirectionDetector.detectAlign(
                        item.title,
                        fallback: ambientDirection,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? ds.textSecondary
                            : ds.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: (dateStr.isNotEmpty || isLoading)
                              ? Text(
                                  dateStr.isEmpty ? 'Loading Date...' : dateStr,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: item.isOverdue(DateTime.now())
                                        ? AppColors.error
                                        : ds.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TodoPriorityIndicator(
                          priority: item.priority,
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
}
