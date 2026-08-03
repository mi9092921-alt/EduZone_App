import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../courses/domain/entities/lesson.dart';
import '../../../courses/domain/entities/section.dart';
import '../../../courses/presentation/providers/courses_provider.dart';
import '../providers/video_provider.dart';
import '../widgets/lessons_sidebar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// مشغّل الدروس الموحّد (Universal Video Player Screen)
//
// يستقبل [playerBuilder] لبناء المشغّل المناسب (YouTube أو Proxy)،
// مما يوحد واجهة المستخدم ومنطق التحكم بالكامل.
// ─────────────────────────────────────────────────────────────────────────────

enum PlayerType { youtube, proxy, modern, player4 }

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  final Widget Function(
    BuildContext context,
    bool isFullScreen,
    VoidCallback toggleFullScreen,
    bool isVertical,
  )
  playerBuilder;
  final PlayerType playerType;

  const VideoPlayerScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.playerBuilder,
    this.playerType = PlayerType.youtube,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isFullScreen = false;
  bool _isVertical = false;

  // مفتاح ثابت (يُنشأ مرة واحدة فقط لكل درس) يحافظ على عنصر شجرة الـ widget
  // الخاص بالمشغّل عند انتقاله بين التخطيط العادي (داخل Column) ووضع ملء
  // الشاشة (body لـ Scaffold مختلف). بدون هذا المفتاح، فلاتر يتعامل مع
  // الانتقال كأنه widget جديد كليًا، فيُدمَّر الـ State (والـ controller
  // الداخلي للفيديو) ويُعاد إنشاؤه من الصفر — وهو ما يسبب إعادة تحميل
  // الفيديو من البداية عند الضغط على زر ملء الشاشة (وينطبق على كل المشغلات
  // الأربعة لأنها كلها تمر من هذه النقطة).
  final GlobalKey _playerKey = GlobalKey();

  @override
  void dispose() {
    _resetOrientation();
    super.dispose();
  }

  void _resetOrientation() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleFullScreen() {
    final newFullScreen = !_isFullScreen;
    setState(() {
      _isFullScreen = newFullScreen;
    });

    if (!kIsWeb) {
      if (newFullScreen) {
        if (_isVertical) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        _resetOrientation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailsProvider(widget.courseId));
    final lessonContentAsync = ref.watch(
      lessonContentProvider(widget.lessonId),
    );
    final ds = AppColors.of(context);

    return courseAsync.when(
      data: (course) {
        final currentLesson = _findLesson(course, widget.lessonId);

        if (currentLesson == null) {
          return AppScreen(
            appBar: AppBar(elevation: 0),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.lessonNotFound,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
              ),
            ),
          );
        }

        return lessonContentAsync.when(
          data: (content) {
            if (!content.hasAccess) {
              return _buildPaywall(context, currentLesson, ds);
            }

            final playerWidget = KeyedSubtree(
              key: _playerKey,
              child: widget.playerBuilder(
                context,
                _isFullScreen,
                _toggleFullScreen,
                _isVertical,
              ),
            );

            if (_isFullScreen) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: playerWidget,
              );
            }

            final videoState = ref.watch(
              videoProgressProvider(widget.courseId, widget.lessonId),
            );

            return AppScreen(
              scrollable: false,
              appBar: AppBar(
                elevation: 0,
                title: Text(currentLesson.title, style: AppTextStyles.h3),
                actions: [
                  _PlayerSwitchButton(
                    courseId: widget.courseId,
                    lessonId: widget.lessonId,
                    playerType: widget.playerType,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── مشغّل الفيديو (Injected) ───────────────────────────
                  playerWidget,

                  if (videoState.progressPct > 0)
                    LinearProgressIndicator(
                      value: videoState.progressPct / 100,
                      backgroundColor: ds.border,
                      color: videoState.isCompleted ? ds.success : ds.primary,
                      minHeight: 4,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        // زر تغيير الابعاد 9:16 , 16:9 للفيديوهات العمودية
                        AppIconButton(
                          icon: _isVertical
                              ? Icons.crop_portrait_rounded
                              : Icons.crop_landscape_rounded,
                          semanticLabel: _isVertical
                              ? AppLocalizations.of(context)!.videoOrientationLandscape
                              : AppLocalizations.of(context)!.videoOrientationPortrait,
                          iconSize: 18,
                          onPressed: () {
                            setState(() {
                              _isVertical = !_isVertical;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: ds.surface2,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // زر ملء الشاشة
                        AppIconButton(
                          icon: Icons.fullscreen_rounded,
                          semanticLabel: AppLocalizations.of(context)!.videoEnterFullscreen,
                          iconSize: 18,
                          onPressed: _toggleFullScreen,
                          style: IconButton.styleFrom(
                            backgroundColor: ds.surface2,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        if (videoState.isCompleted) ...[
                          const Spacer(),
                          Icon(
                            Icons.check_circle_rounded,
                            color: ds.success,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: ds.border),

                  // ─── قائمة الدروس الجانبية ───────────────────────────────
                  Expanded(
                    child: LessonsSidebar(
                      course: course,
                      currentLessonId: widget.lessonId,
                      onLessonTap: (newId) {
                        if (newId != widget.lessonId) {
                          final route = widget.playerType == PlayerType.proxy
                              ? 'lesson2'
                              : widget.playerType == PlayerType.modern
                              ? 'lesson3'
                              : widget.playerType == PlayerType.player4
                              ? 'lesson4'
                              : 'lesson';
                          context.replace(
                            '${AppRoutes.courses}/${widget.courseId}/$route/$newId',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () =>
              AppSkeleton(child: _buildSkeletonLayout(context)),
          error: (e, _) => AppScreen(
            child: Center(
              child: Text(AppLocalizations.of(context)!.errorLoading(e.toString())),
            ),
          ),
        );
      },
      loading: () =>
          AppSkeleton(child: _buildSkeletonLayout(context)),
      error: (e, _) => AppScreen(
        child: Center(
          child: Text(AppLocalizations.of(context)!.errorLoading(e.toString())),
        ),
      ),
    );
  }

  Lesson? _findLesson(Course course, String lessonId) {
    final sections = course.sections ?? const <Section>[];

    for (final section in sections) {
      final lessons = section.lessons ?? const <Lesson>[];

      for (final lesson in lessons) {
        if (lesson.id == lessonId) return lesson;
      }
    }
    return null;
  }

  Widget _buildPaywall(
    BuildContext context,
    Lesson lesson,
    DesignSystemColors ds,
  ) {
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

  Widget _buildSkeletonLayout(BuildContext context) {
    return AppScreen(
      scrollable: false,
      appBar: AppBar(
        elevation: 0,
        title: Container(width: 150, height: 20, color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(height: 24, color: Colors.white),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, i) => ListTile(
                leading: Container(width: 40, height: 40, color: Colors.white),
                title: Container(height: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSwitchButton extends StatelessWidget {
  final String courseId;
  final String lessonId;
  final PlayerType playerType;

  const _PlayerSwitchButton({
    required this.courseId,
    required this.lessonId,
    required this.playerType,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: playerType == PlayerType.proxy
          ? Icons.shield_rounded
          : playerType == PlayerType.modern
          ? Icons.auto_awesome_rounded
          : playerType == PlayerType.player4
          ? Icons.play_circle_outline_rounded
          : Icons.smart_display_rounded,
      semanticLabel: AppLocalizations.of(context)!.videoSwitchPlayer,
      onPressed: () => _showSwitchSheet(context),
    );
  }

  void _showSwitchSheet(BuildContext context) {
    final ds = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ds.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.chooseVideoPlayer,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlayerOption(
              icon: Icons.smart_display_rounded,
              title: AppLocalizations.of(context)!.youtubePlayer,
              subtitle: AppLocalizations.of(context)!.youtubePlayerSubtitle,
              isActive: playerType == PlayerType.youtube,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.youtube) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson/$lessonId',
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              icon: Icons.shield_rounded,
              title: AppLocalizations.of(context)!.proxyPlayer,
              subtitle: AppLocalizations.of(context)!.proxyPlayerSubtitle,
              isActive: playerType == PlayerType.proxy,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.proxy) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson2/$lessonId',
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              icon: Icons.auto_awesome_rounded,
              title: AppLocalizations.of(context)!.modernPlayer,
              subtitle: AppLocalizations.of(context)!.modernPlayerSubtitle,
              isActive: playerType == PlayerType.modern,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.modern) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson3/$lessonId',
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _PlayerOption(
              icon: Icons.play_circle_outline_rounded,
              title: AppLocalizations.of(context)!.directPlayer,
              subtitle: AppLocalizations.of(context)!.directPlayerSubtitle,
              isActive: playerType == PlayerType.player4,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.player4) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson4/$lessonId',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _PlayerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : ds.surface2,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : ds.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.primary : ds.textSecondary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}