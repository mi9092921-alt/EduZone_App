import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Thin, inset divider used between rows inside a settings `AppCard`.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: AppSpacing.md,
      color: color.withValues(alpha: 0.5),
    );
  }
}
