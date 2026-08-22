import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../shared/cross_feature/downloads_shared.dart';
import '../../../../../shared/utils/app_snackbar.dart';
import '../../../../../shared/utils/error_handler.dart';
import '../../../../downloads/domain/entities/download_enums.dart';
import '../../../application/providers/courses_provider.dart';
import '../../../data/services/watched_lessons_service.dart';
import '../../../domain/entities/lesson.dart';
import '../../../domain/entities/lesson_content.dart';
import '../../../domain/entities/section.dart';
import 'enrollment_required_dialog.dart';
import 'lesson_tile_wrapper.dart';
import 'player_choice_sheet.dart';

/// Structure note: state management (last-watched/local-watched
/// preferences, watched-status toggling with optimistic update + revert,
/// the download flow) stays in this file — it's one cohesive unit driven
/// by `setState`/`mounted`/provider reads, and minimizing behavioral risk
/// matters more than file length. The purely presentational pieces (player
/// choice sheet, player option tile, enrollment dialog) and the
/// self-contained [LessonTileWrapper] have been extracted into sibling
/// files in this folder.
class SectionsAccordion extends ConsumerStatefulWidget {
  final Section section;
  final String courseId;
  final String courseTitle;
  final bool isEnrolled;

  const SectionsAccordion({
    super.key,
    required this.section,
    required this.courseId,
    required this.courseTitle,
    this.isEnrolled = false,
  });

  @override
  ConsumerState<SectionsAccordion> createState() => _SectionsAccordionState();
}

class _SectionsAccordionState extends ConsumerState<SectionsAccordion> {
  String? _lastWatchedLessonId;
  final Set<String> _localWatchedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final lastId = prefs.getString(
      StorageKeys.lastWatchedLesson(int.tryParse(widget.courseId) ?? 0),
    );

    // Load local watched status for each lesson
    if (widget.section.lessons != null) {
      for (final lesson in widget.section.lessons!) {
        final isWatched = await WatchedLessonsService.isLessonWatched(
          lesson.id,
        );
        if (isWatched) _localWatchedIds.add(lesson.id);
      }
    }

    if (mounted) {
      setState(() {
        _lastWatchedLessonId = lastId;
      });
    }
  }

  Future<void> _saveLastWatched(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.lastWatchedLesson(int.tryParse(widget.courseId) ?? 0),
      lessonId,
    );

    if (mounted) {
      setState(() {
        _lastWatchedLessonId = lessonId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final lessons = widget.section.lessons ?? [];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          widget.section.title,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: ds.textPrimary,
          ),
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.lessonsCount(lessons.length),
          style: AppTextStyles.bodySmall.copyWith(color: ds.textSecondary),
        ),
        childrenPadding: EdgeInsets.zero,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: lessons.map((lesson) {
          final userProgress = lesson.userProgress?.isNotEmpty == true
              ? lesson.userProgress!.first
              : null;

          final isCompleted =
              (userProgress?.completed ?? false) ||
              _localWatchedIds.contains(lesson.id);
          final isLastWatched = _lastWatchedLessonId == lesson.id.toString();

          return LessonTileWrapper(
            lesson: lesson,
            courseId: widget.courseId,
            courseTitle: widget.courseTitle,
            isEnrolled: widget.isEnrolled,
            isCompleted: isCompleted,
            isLastWatched: isLastWatched,
            onTap: () => _handleLessonTap(context, lesson),
            onToggleCompleted: (value) =>
                _handleToggleWatched(lesson.id, value ?? false),
            onDownload: () => _handleDownload(lesson),
          );
        }).toList(),
      ),
    );
  }

  void _handleLessonTap(BuildContext context, Lesson lesson) {
    if (!widget.isEnrolled && !lesson.isPreview) {
      showEnrollmentRequiredDialog(context);
      return;
    }

    _saveLastWatched(lesson.id.toString());
    _handleToggleWatched(lesson.id, true); // Mark as watched automatically

    showPlayerChoiceSheet(
      context,
      onPlayerSelected: (playerType) =>
          _handlePlayerChoice(context, lesson, playerType),
    );
  }

  Future<void> _handleToggleWatched(String lessonId, bool isWatched) async {
    // Update local preferences
    await WatchedLessonsService.toggleWatchedStatus(lessonId, isWatched);

    // Update local UI state optimistically
    if (mounted) {
      setState(() {
        if (isWatched) {
          _localWatchedIds.add(lessonId);
        } else {
          _localWatchedIds.remove(lessonId);
        }
      });
    }

    // Update progress on the backend
    final repo = ref.read(coursesRepositoryProvider);
    final result = await repo.updateLessonProgress(
      courseId: widget.courseId,
      lessonId: lessonId,
      completed: isWatched,
      progressPct: isWatched ? 100.0 : 0.0,
    );

    result.fold(
      (failure) {
        debugPrint('Failed to update progress on server: ${failure.message}');
        if (mounted) {
          AppSnackbar.showError(context: context, message: failure.message);
          // Revert optimistic update on failure
          setState(() {
            if (isWatched) {
              _localWatchedIds.remove(lessonId);
            } else {
              _localWatchedIds.add(lessonId);
            }
          });
          // Revert local preferences
          WatchedLessonsService.toggleWatchedStatus(lessonId, !isWatched);
        }
      },
      (_) {
        // On success, invalidate the providers to refresh remote data
        if (mounted) {
          ref.invalidate(courseProgressProvider(widget.courseId));
          ref.invalidate(myCoursesProvider);
        }
      },
    );
  }

  void _handlePlayerChoice(
    BuildContext context,
    Lesson lesson,
    String playerType,
  ) async {
    if (context.mounted) {
      Navigator.pop(context);
      _navigateToPlayer(context, lesson, playerType);
    }
  }

  void _navigateToPlayer(
    BuildContext context,
    Lesson lesson,
    String playerType,
  ) {
    final subPath = playerType == 'modern'
        ? 'lesson3'
        : playerType == 'player4'
        ? 'lesson4'
        : 'lesson';
    context.push(
      '${AppRoutes.courses}/${widget.courseId}/$subPath/${lesson.id}',
    );
  }

  void _handleDownload(Lesson lesson) async {
    final l10n = AppLocalizations.of(context)!;

    if (!widget.isEnrolled && !lesson.isPreview) {
      if (mounted) showEnrollmentRequiredDialog(context);
      return;
    }
    final lessonIdStr = lesson.id.toString();

    // Check if the lesson content is already loaded or loading
    final lessonContentAsync = ref.read(lessonContentProvider(lessonIdStr));
    if (lessonContentAsync.isLoading) {
      FeedbackService.show(context, message: l10n.loadingLessonData);
    }

    final LessonContent content;
    try {
      content = await ref.read(lessonContentProvider(lessonIdStr).future);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context: context,
        // e is a typed AppException (see courses_remote_ds_impl.dart's
        // NetworkGuard/NetworkExceptionMapper wiring) whose `.toString()`
        // was previously interpolated directly into this l10n string --
        // an internal, unlocalized diagnostic ("AppException(code):
        // message"), not something meant for a user-facing snackbar.
        // Classify it the same way every other network-error display in
        // the app does.
        message: l10n.downloadStartFailed(ErrorHandler.getMessage(context, e)),
      );
      return;
    }

    if (!mounted) return;
    if (!content.hasAccess) {
      showEnrollmentRequiredDialog(context);
      return;
    }

    final localCourseId = widget.courseId;
    final localLessonId = lessonIdStr;
    final localLessonTitle = lesson.title;

    var videoUrl = content.videoUrl?.trim() ?? '';
    if (videoUrl.isNotEmpty &&
        content.provider == 'youtube' &&
        !videoUrl.startsWith('http')) {
      videoUrl = 'https://www.youtube.com/watch?v=$videoUrl';
    }

    if (videoUrl.isEmpty) {
      AppSnackbar.showError(context: context, message: l10n.videoUrlError);
      return;
    }

    final remote = ref.read(downloadRemoteDataSourceProvider);
    try {
      final videoInfo = await remote.getVideoInfo(videoUrl);
      if (!mounted) return;

      final availableQualities = videoInfo.supportedQualities.isNotEmpty
          ? videoInfo.supportedQualities
          : VideoQuality.values;

      await showQualitySelector(
        context: context,
        lessonTitle: localLessonTitle,
        videoInfo: videoInfo,
        availableQualities: availableQualities,
        onQualitySelected: (quality) async {
          if (!mounted) return;

          FeedbackService.show(context, message: l10n.downloadStarting);

          try {
            await ref
                .read(downloadsProvider.notifier)
                .startDownload(
                  lessonId: localLessonId,
                  courseId: localCourseId,
                  courseTitle: widget.courseTitle,
                  title: localLessonTitle,
                  videoUrl: videoUrl,
                  quality: quality,
                );
            if (!mounted) return;
            AppSnackbar.showSuccess(
              context: context,
              message: l10n.downloadStartedSuccess(quality.label),
            );
          } catch (e) {
            if (!mounted) return;
            AppSnackbar.showError(
              context: context,
              message: l10n.downloadStartFailed(ErrorHandler.getMessage(context, e)),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context: context,
        message: l10n.videoInfoFetchFailed(ErrorHandler.getMessage(context, e)),
      );
    }
  }
}
