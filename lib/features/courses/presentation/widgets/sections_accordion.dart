import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/components/lesson_tile.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../downloads/domain/entities/download_enums.dart';
import '../../../downloads/domain/entities/downloaded_lesson.dart';
import '../../../downloads/presentation/providers/downloads_provider.dart';
import '../../../downloads/presentation/widgets/quality_selector.dart';
import '../../data/services/watched_lessons_service.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/lesson_content.dart';
import '../../domain/entities/section.dart';
import '../providers/courses_provider.dart';

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
      _showEnrollmentRequiredDialog(context);
      return;
    }

    _saveLastWatched(lesson.id.toString());
    _handleToggleWatched(lesson.id, true); // Mark as watched automatically

    _showPlayerChoiceSheet(context, lesson);
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
          AppSnackbar.showError(
            context: context,
            message: failure.message,
          );
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

  void _showPlayerChoiceSheet(BuildContext context, Lesson lesson) {
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ds.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'اختر المشغل',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlayerOption(
              title: 'YouTube Player',
              subtitle: 'مشغّل Flutter القياسي',
              icon: Icons.smart_display_rounded,
              onTap: () => _handlePlayerChoice(context, lesson, 'youtube'),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              title: 'Proxy Player',
              subtitle: 'مشغّل بدون إعلانات',
              icon: Icons.shield_rounded,
              onTap: () => _handlePlayerChoice(context, lesson, 'proxy'),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              title: 'Modern Player',
              subtitle: 'مشغّل WebView مع حذف العناصر',
              icon: Icons.auto_awesome_rounded,
              onTap: () => _handlePlayerChoice(context, lesson, 'modern'),
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              title: AppLocalizations.of(context)!.directPlayer,
              subtitle: AppLocalizations.of(context)!.directPlayerSubtitle,
              icon: Icons.play_circle_outline_rounded,
              onTap: () => _handlePlayerChoice(context, lesson, 'player4'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
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
    final subPath = playerType == 'proxy'
        ? 'lesson2'
        : playerType == 'modern'
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
      if (mounted) _showEnrollmentRequiredDialog(context);
      return;
    }
    final lessonIdStr = lesson.id.toString();

    // Check if the lesson content is already loaded or loading
    final lessonContentAsync = ref.read(lessonContentProvider(lessonIdStr));
    if (lessonContentAsync.isLoading) {
      FeedbackService.show(
        context,
        message: l10n.loadingLessonData,
      );
    }

    final LessonContent content;
    try {
      content = await ref.read(lessonContentProvider(lessonIdStr).future);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context: context,
        message: l10n.downloadStartFailed(e.toString()),
      );
      return;
    }

    if (!mounted) return;
    if (!content.hasAccess) {
      _showEnrollmentRequiredDialog(context);
      return;
    }

    final localCourseId = widget.courseId;
    final localLessonId = lessonIdStr;
    final localLessonTitle = lesson.title;
    
    var videoUrl = content.videoUrl?.trim() ?? '';
    if (videoUrl.isNotEmpty && content.provider == 'youtube' && !videoUrl.startsWith('http')) {
      videoUrl = 'https://www.youtube.com/watch?v=$videoUrl';
    }

    if (videoUrl.isEmpty) {
      AppSnackbar.showError(
        context: context,
        message: l10n.videoUrlError,
      );
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

          FeedbackService.show(
            context,
            message: l10n.downloadStarting,
          );

          try {
            await ref.read(downloadsProvider.notifier).startDownload(
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
            final message = e is Failure ? e.message : e.toString();
            AppSnackbar.showError(
              context: context,
              message: l10n.downloadStartFailed(message),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(
        context: context,
        message: l10n.videoInfoFetchFailed(e.toString()),
      );
    }
  }

  void _showEnrollmentRequiredDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.enrollmentRequired),
        content: Text(l10n.enrollToAccessLesson),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to enrollment or show options
            },
            child: Text(l10n.viewEnrollmentOptions),
          ),
        ],
      ),
    );
  }
}

class _PlayerOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PlayerOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ds = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: ds.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: ds.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class LessonTileWrapper extends ConsumerWidget {
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final bool isEnrolled;
  final bool isCompleted;
  final bool isLastWatched;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleCompleted;
  final VoidCallback onDownload;

  const LessonTileWrapper({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.isEnrolled,
    required this.isCompleted,
    required this.isLastWatched,
    required this.onTap,
    required this.onToggleCompleted,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadsProvider);
    final downloads = downloadsAsync.value ?? [];
    
    DownloadedLesson? download;
    for (final d in downloads) {
      if (d.lessonId == lesson.id.toString()) {
        download = d;
        break;
      }
    }

    bool isDownloaded = download?.status == DownloadStatus.completed;
    bool isDownloading = download?.status == DownloadStatus.downloading ||
        download?.status == DownloadStatus.pending;
    bool downloadFailed = download?.status == DownloadStatus.failed;
    double progressPct = download?.progress ?? 0.0;

    if (download != null &&
        (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.pending)) {
      final progressAsync = ref.watch(downloadProgressProvider(download.id));
      final progress = progressAsync.value;
      if (progress != null) {
        isDownloading = progress.status == DownloadStatus.downloading ||
            progress.status == DownloadStatus.pending;
        isDownloaded = progress.status == DownloadStatus.completed;
        downloadFailed = progress.status == DownloadStatus.failed;
        progressPct = progress.progress;
      }
    }

    return LessonTile(
      title: lesson.title,
      completed: isCompleted,
      isLastWatched: isLastWatched,
      isLocked: !isEnrolled && !lesson.isPreview,
      isFree: !isEnrolled && lesson.isPreview,
      isEnrolled: isEnrolled,
      onTap: onTap,
      onToggleCompleted: onToggleCompleted,
      onDownload: onDownload,
      isDownloading: isDownloading,
      isDownloaded: isDownloaded,
      downloadFailed: downloadFailed,
      downloadProgress: progressPct,
    );
  }
}

