import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../application/providers/todo_provider.dart';
import '../../domain/entities/todo_item.dart';
import '../widgets/add_todo_bottom_sheet.dart';
import '../widgets/variants/todo_list_tile.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final l10n = AppLocalizations.of(context)!;

    final allTodos = [...todoState.todos]
      ..sort((a, b) {
        // 1. Completion status (Pending first)
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;

        // 2. Due Date (Nearest first)
        if (a.dueAt != null && b.dueAt != null) {
          final dateComparison = a.dueAt!.compareTo(b.dueAt!);
          if (dateComparison != 0) return dateComparison;
        } else if (a.dueAt != null) {
          return -1;
        } else if (b.dueAt != null) {
          return 1;
        }

        // 3. Priority (Highest last / at the end)
        return a.priority.compareTo(b.priority);
      });

    return AppScreen(
      scrollable: false,
      safeArea: false,
      onRefresh: () => ref.read(todoProvider.notifier).fetchTodos(),
      error: todoState.error != null && todoState.todos.isEmpty
          ? ErrorHandler.getMessage(context, todoState.error!)
          : null,
      onRetry: () => ref.read(todoProvider.notifier).fetchTodos(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: () => _showAddTodoSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          child: const Icon(AppIcons.add, size: 28),
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.transparent,
            elevation: 0,
            flexibleSpace: AppModernHeader(
              title: l10n.tasksTitle,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            sliver: todoState.isLoading && todoState.todos.isEmpty
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AppSkeleton(
                        child: TodoListTile(
                          todo: TodoItem.skeleton(),
                          onStatusChanged: (_) {},
                          onDelete: () {},
                        ),
                      ),
                      childCount: 5,
                    ),
                  )
                : _buildTodoList(context, ref, allTodos, l10n),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  void _showAddTodoSheet(BuildContext context, {TodoItem? todoToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => AddTodoBottomSheet(todoToEdit: todoToEdit),
    );
  }

  Future<void> _onDeletePressed(
    BuildContext context,
    WidgetRef ref,
    TodoItem todo,
    AppLocalizations l10n,
  ) async {
    final deleted = await ref.read(todoProvider.notifier).deleteTodo(todo.id);

    if (!deleted) {
      if (!context.mounted) return;
      FeedbackService.show(
        context,
        message: l10n.errorLoadingTasks,
        type: FeedbackType.error,
      );
      return;
    }

    if (!context.mounted) return;
    FeedbackService.show(
      context,
      message: l10n.taskDeleted,
      type: FeedbackType.success,
    );
  }

  Widget _buildTodoList(
    BuildContext context,
    WidgetRef ref,
    List<TodoItem> todos,
    AppLocalizations l10n,
  ) {
    if (todos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          isFullPage: false,
          icon: AppIcons.task,
          title: l10n.noTasks,
          description: l10n.no_tasks_desc,
          actionLabel: l10n.addTask,
          onActionPressed: () => _showAddTodoSheet(context),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final todo = todos[index];
        return TodoListTile(
          todo: todo,
          onStatusChanged: (value) {
            if (value != null) {
              ref
                  .read(todoProvider.notifier)
                  .toggleTodoStatus(todo.id, todo.isCompleted);
            }
          },
          onEdit: () => _showAddTodoSheet(context, todoToEdit: todo),
          onDelete: () => _onDeletePressed(context, ref, todo, l10n),
        );
      }, childCount: todos.length),
    );
  }
}
