import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/models/todo_item.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../application/providers/todo_provider.dart';
import '../widgets/add_todo_bottom_sheet.dart';
import '../widgets/variants/todo_list_tile.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final l10n = AppLocalizations.of(context)!;

    // Phase 8: toggle/add/update failures set `TodoState.error` while the
    // (still valid) list stays on screen — previously nothing rendered for
    // them (the full-page error below only fires when the list is empty),
    // so a failed mutation was indistinguishable from an unacknowledged
    // success. Surface it as the standard classified snackbar instead,
    // gated on the same non-empty-list condition so the empty-list case
    // keeps its single full-page error treatment (no double reporting).
    ref.listen<TodoState>(todoProvider, (previous, next) {
      if (next.error == null ||
          identical(previous?.error, next.error) ||
          next.todos.isEmpty) {
        return;
      }
      if (!context.mounted) return;
      ErrorHandler.handle(context, next.error!);
    });

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
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: FloatingActionButton(
          onPressed: () => _showAddTodoSheet(context),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.neutral0,
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
      // Phase 8: classify via ErrorHandler instead of the previous
      // l10n.errorLoadingTasks (a "loading" message for a delete failure);
      // the notifier stored the typed failure on TodoState.error.
      final failure = ref.read(todoProvider).error;
      FeedbackService.show(
        context,
        message: failure != null
            ? ErrorHandler.getMessage(context, failure)
            : l10n.errorGeneric,
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
      // P8.8 fix: stable per-item keys so list diffing matches tiles by
      // todo identity, not slot position, when the list reorders (due_at/
      // priority resort after a toggle) or shrinks (delete) — consistent
      // with the key: ValueKey(...) already used on course-card items
      // elsewhere (e.g. DiscoverCourseCard).
      delegate: SliverChildBuilderDelegate((context, index) {
        final todo = todos[index];
        return TodoListTile(
          key: ValueKey(todo.id),
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
