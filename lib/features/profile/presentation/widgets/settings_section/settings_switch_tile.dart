import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/widgets/app_icon_container.dart';

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.semanticsLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return Semantics(
      label: semanticsLabel,
      toggled: value,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            AppIconContainer(icon: icon, padding: 6),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge.copyWith(
                    color: ds.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle!, style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                      height: 1.3,
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(value: value, onChanged: onChanged, activeColor: ds.primary),
          ],
        ),
      ),
    );
  }
}
