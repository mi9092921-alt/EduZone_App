import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String? label;
  final EdgeInsetsGeometry padding;

  const TodoCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.padding = const EdgeInsets.all(AppSpacing.xs),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: value,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: padding,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: Curves.easeOutBack,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? AppColors.success : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: value
                    ? AppColors.success
                    : AppColors.of(context).textMuted.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: value ? AppShadows.level1 : [],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: value
                    ? const Icon(
                        Icons.check,
                        key: ValueKey('checked'),
                        color: Colors.white,
                        size: 16,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
