import 'package:app/core/utils/text_direction_detector.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoContent extends StatelessWidget {
  final String title;
  final bool isCompleted;

  const TodoContent({
    super.key,
    required this.title,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    // The todo title is free-form user content and may be written in a
    // different language/script than the app's current UI locale. Detect
    // its direction independently instead of inheriting the ambient
    // Directionality from MaterialApp's `locale`.
    final textDirection = TextDirectionDetector.detect(title);

    return Directionality(
      textDirection: textDirection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textDirection: textDirection,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              color: isCompleted ? ds.textMuted : ds.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}