import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Bold, primary-colored section title used above each settings card
/// ("Settings", "Permissions", "Support & Info").
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: AppTextStyles.h3.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
