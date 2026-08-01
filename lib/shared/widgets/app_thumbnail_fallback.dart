import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';

/// A shared fallback widget displayed when a course thumbnail URL is absent.
/// Replaces the duplicated private `_ThumbnailFallback` that existed in both
/// [CoursePreviewScreen] and [CourseDetailsScreen].
class AppThumbnailFallback extends StatelessWidget {
  final DesignSystemColors ds;

  const AppThumbnailFallback({super.key, required this.ds});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: ds.surface2),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          color: ds.textMuted.withValues(alpha: 0.2),
          size: 64,
        ),
      ),
    );
  }
}
