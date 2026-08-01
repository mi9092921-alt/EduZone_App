import 'package:app/design_system/design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingPickerOption<T> {
  const SettingPickerOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

Future<void> showSettingPicker<T>({
  required BuildContext context,
  required String title,
  required String cancelLabel,
  required List<SettingPickerOption<T>> options,
  required T currentValue,
  required ValueChanged<T> onSelected,
}) async {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text(title),
          actions: options.map((option) {
            final isSelected = option.value == currentValue;
            return CupertinoActionSheetAction(
              onPressed: () {
                onSelected(option.value);
                Navigator.of(sheetContext).pop();
              },
              isDefaultAction: isSelected,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(option.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(option.label),
                ],
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelLabel),
          ),
        );
      },
    );
    return;
  }

  // Fix: this used to be a raw `showMenu`/`PopupMenuItem` dropdown —
  // default Material colors/radius (ignoring the app's design tokens),
  // no title or cancel button shown at all (both params were silently
  // unused here), and anchored to the tapped SettingsTile's full-width
  // RenderBox rather than a small button, which made the popup look and
  // feel out of place compared to the rest of the app. Replaced with a
  // modal bottom sheet styled like the app's other sheets (see
  // EditProfileBottomSheet) so it matches the design system and
  // actually shows the title/cancel label.
  final scheme = Theme.of(context).colorScheme;

  final selected = await showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) {
      final colors = AppColors.of(sheetContext);

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle, consistent with the app's other bottom sheets.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: AppRadius.fullBorder,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Text(
                  title,
                  style: AppTextStyles.h3.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final option in options)
                _SettingPickerOptionTile(
                  option: option,
                  isSelected: option.value == currentValue,
                  colors: colors,
                  onTap: () => Navigator.of(sheetContext).pop(option.value),
                ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected != null) {
    onSelected(selected);
  }
}

class _SettingPickerOptionTile<T> extends StatelessWidget {
  const _SettingPickerOptionTile({
    required this.option,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final SettingPickerOption<T> option;
  final bool isSelected;
  final DesignSystemColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = colors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 20,
              color: isSelected ? activeColor : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                option.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? activeColor : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 20, color: activeColor),
          ],
        ),
      ),
    );
  }
}
