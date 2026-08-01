import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const TodoCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
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
    );
  }
}
