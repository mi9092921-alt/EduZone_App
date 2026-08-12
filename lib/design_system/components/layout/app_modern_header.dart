import 'dart:ui';
import 'package:flutter/material.dart';

import '../../tokens/app_spacing.dart';
import '../../tokens/app_text_styles.dart';

class AppModernHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBlur;
  final bool centerTitle;

  const AppModernHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showBlur = true,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: showBlur ? 15 : 0,
          sigmaY: showBlur ? 15 : 0,
        ),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.78),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: NavigationToolbar(
            leading: leading,
            middle: Text(
              title,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) ??
                  AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: actions != null
                ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
                : null,
            centerMiddle: centerTitle,
            middleSpacing: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
