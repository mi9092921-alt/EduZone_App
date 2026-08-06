import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Trailing "current value + chevron" display used on settings tiles
/// (e.g. the current theme or language), truncating long values.
class SettingsValueDisplay extends StatelessWidget {
  const SettingsValueDisplay({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          AppIcons.arrowForward,
          size: 14,
          color: ds.textSecondary.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}
