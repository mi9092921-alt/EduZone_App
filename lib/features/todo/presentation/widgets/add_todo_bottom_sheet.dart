// Design System Imports
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/todo_item.dart';
import '../providers/todo_provider.dart';

class AddTodoBottomSheet extends ConsumerStatefulWidget {
  final TodoItem? todoToEdit;

  const AddTodoBottomSheet({super.key, this.todoToEdit});

  @override
  ConsumerState<AddTodoBottomSheet> createState() => _AddTodoBottomSheetState();
}

class _AddTodoBottomSheetState extends ConsumerState<AddTodoBottomSheet> {
  final _titleController = TextEditingController();
  DateTime? _dueAt;
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    if (widget.todoToEdit != null) {
      _titleController.text = widget.todoToEdit!.title;
      _dueAt = widget.todoToEdit!.dueAt;
      _priority = widget.todoToEdit!.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTodo() async {
    final l10n = AppLocalizations.of(context)!;
    if (_titleController.text.trim().isEmpty) return;

    // Improved ID retrieval with logging for debugging
    final authState = ref.read(authProvider);
    final authUser = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final userId =
        authUser?.id ?? SupabaseService.client.auth.currentUser?.id ?? '';
    final tenantId = authUser?.tenantId ?? '';

    if (userId.isEmpty || tenantId.isEmpty) {
      debugPrint(
        '[AddTodo] ID mismatch: userId="$userId", tenantId="$tenantId"',
      );
      if (mounted) {
        FeedbackService.show(
          context,
          message: l10n.errorGeneric,
          type: FeedbackType.error,
        );
      }
      return;
    }

    final newTodo = TodoItem(
      id: widget.todoToEdit?.id ?? const Uuid().v4(),
      userId: userId,
      tenantId: tenantId,
      title: _titleController.text.trim(),
      priority: _priority,
      isCompleted: widget.todoToEdit?.isCompleted ?? false,
      dueAt: _dueAt,
      createdAt: widget.todoToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.todoToEdit != null) {
        await ref.read(todoProvider.notifier).updateTodo(newTodo);
        if (mounted) {
          FeedbackService.show(
            context,
            message: l10n.taskUpdated,
            type: FeedbackType.success,
          );
        }
      } else {
        await ref.read(todoProvider.notifier).addTodo(newTodo);
        if (mounted) {
          FeedbackService.show(
            context,
            message: l10n.taskAdded,
            type: FeedbackType.success,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        FeedbackService.show(
          context,
          message: l10n.errorGeneric,
          type: FeedbackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return Material(
      color: ds.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: AppSpacing.xl,
          end: AppSpacing.xl,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: Material(
                  color: ds.border,
                  borderRadius: BorderRadius.circular(2),
                  child: const SizedBox(width: 40, height: 4),
                ),
              ),
            ),
            Text(
              widget.todoToEdit == null
                  ? AppLocalizations.of(context)!.addTask
                  : AppLocalizations.of(context)!.editTask,
              style: AppTextStyles.h2.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              label: AppLocalizations.of(context)!.taskTitleHint,
              controller: _titleController,
              prefixIcon: AppIcons.task,
              autofocus: true,
              autoExpand: true,
              autoDetectDirection: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    initialValue: _priority,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: ds.textPrimary,
                    ),
                    dropdownColor: ds.surface,
                    icon: Icon(Icons.arrow_drop_down, color: ds.textSecondary),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.taskPriority,
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: ds.textSecondary,
                      ),
                      prefixIcon: Icon(
                        AppIcons.priority,
                        size: 20,
                        color: ds.textSecondary,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: ds.border),
                        borderRadius: AppRadius.xsBorder,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: AppRadius.xsBorder,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Text(
                          AppLocalizations.of(context)!.priorityNormal,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(
                          AppLocalizations.of(context)!.priorityMedium,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text(AppLocalizations.of(context)!.priorityHigh),
                      ),
                    ],
                    onChanged: (val) {
                      debugPrint('[AddTodo] Priority Changed to: $val');
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: AppCard(
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        debugPrint('[AddTodo] Opening Date Picker');
                        final today = DateUtils.dateOnly(DateTime.now());

                        // Ensure initialDate is not before firstDate or after lastDate to avoid Flutter crash
                        DateTime initialDate = today;
                        if (_dueAt != null) {
                          if (_dueAt!.isBefore(today)) {
                            initialDate = today;
                          } else {
                            initialDate = _dueAt!;
                          }
                        }

                        final lastDate = today.add(const Duration(days: 3650));
                        if (initialDate.isAfter(lastDate)) {
                          initialDate = lastDate;
                        }

                        final date = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: today,
                          lastDate: lastDate,
                          builder: (context, child) {
                            final cs = Theme.of(context).colorScheme;
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: cs.copyWith(
                                  surface: ds.surface,
                                  onSurface: ds.textPrimary,
                                  primary: ds.primary,
                                  onPrimary: AppColors.neutral0,
                                  outline: ds.border,
                                ),
                                datePickerTheme: DatePickerThemeData(
                                  backgroundColor: ds.surface,
                                  headerBackgroundColor: ds.primary,
                                  headerForegroundColor: AppColors.neutral0,
                                  dayForegroundColor: WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return AppColors.neutral0;
                                      }
                                      if (states.contains(WidgetState.disabled)) {
                                        return ds.textMuted;
                                      }
                                      return ds.textPrimary;
                                    },
                                  ),
                                  dayBackgroundColor: WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return ds.primary;
                                      }
                                      return null;
                                    },
                                  ),
                                  todayForegroundColor: WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return AppColors.neutral0;
                                      }
                                      return ds.primary;
                                    },
                                  ),  
                                  todayBackgroundColor: WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return ds.primary;
                                      }
                                      return null;
                                    },
                                  ),
                                  todayBorder: BorderSide(color: ds.primary),
                                  dividerColor: ds.border.withValues(alpha: 0.1),
                                  surfaceTintColor: Colors.transparent,
                                ),
                                dialogTheme: DialogThemeData(
                                  backgroundColor: ds.surface,
                                  surfaceTintColor: Colors.transparent,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          debugPrint('[AddTodo] Date Selected: $date');
                          setState(() => _dueAt = date);
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      elevated: false,
                      backgroundColor: AppColors.transparent,
                      borderColor: _dueAt != null
                          ? AppColors.primary
                          : ds.border,
                      borderRadius: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.event,
                            size: 18,
                            color: _dueAt != null
                                ? AppColors.primary
                                : ds.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _dueAt == null
                                  ? AppLocalizations.of(context)!.dueDateLabel
                                  : DateFormat(
                                      'MMM d',
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ).format(_dueAt!),
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _dueAt != null
                                    ? AppColors.primary
                                    : ds.textSecondary,
                                fontWeight: _dueAt != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl2),
            AppButton(
              label: widget.todoToEdit == null
                  ? AppLocalizations.of(context)!.addBtn
                  : AppLocalizations.of(context)!.editTask,
              onPressed: _saveTodo,
            ),
          ],
        ),
      ),
    );
  }
}
