import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown instead of the player when [lesson]'s content requires enrollment
/// the current user doesn't have (`content.hasAccess == false`).
///
/// Extracted from `video_player_screen.dart`'s private `_buildPaywall`
/// method so it's independently reusable/testable — same layout and copy,
/// no behavior change.
class VideoLessonPaywall extends StatelessWidget {
  final Lesson lesson;

  const VideoLessonPaywall({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return AppScreen(
      appBar: AppBar(
        elevation: 0,
        title: Text(lesson.title, style: AppTextStyles.h3),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: ds.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.lock, size: 48, color: ds.primary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppLocalizations.of(context)!.enrollmentRequired,
                style: AppTextStyles.h2.copyWith(color: ds.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context)!.enrollToAccessLesson,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl2),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(
                  AppLocalizations.of(context)!.viewEnrollmentOptions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
