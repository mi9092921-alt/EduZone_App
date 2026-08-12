import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../../application/providers/video_provider.dart';
import '../widgets/lessons_sidebar.dart';
import 'video_player/lesson_lookup.dart';
import 'video_player/player_switch_sheet.dart';
import 'video_player/player_type.dart';
import 'video_player/video_lesson_paywall.dart';
import 'video_player/video_player_skeleton.dart';

export 'video_player/player_type.dart';

// ─────────────────────────────────────────────────────────────────────────────
// مشغّل الدروس الموحّد (Universal Video Player Screen)
//
// يستقبل [playerBuilder] لبناء المشغّل المناسب (YouTube أو Proxy)،
// مما يوحد واجهة المستخدم ومنطق التحكم بالكامل.
//
// هذا الملف كان أصلاً 566 سطرًا بملف واحد. بعد التقسيم:
//   - video_player_screen.dart              → هذا الملف: التحكّم بالحالة + build()
//   - video_player/player_type.dart          → enum PlayerType (يُصدَّر من هنا
//                                               عبر export فلا تحتاج شاشات
//                                               أخرى تعديل استيرادها)
//   - video_player/lesson_lookup.dart        → findLessonById() — منطق صرف
//                                               قابل للاختبار بدون widgets
//   - video_player/video_player_skeleton.dart → حالة التحميل
//   - video_player/video_lesson_paywall.dart  → شاشة "يتطلب تسجيل"
//   - video_player/player_switch_sheet.dart   → زر ونافذة تبديل المشغّل
// ─────────────────────────────────────────────────────────────────────────────

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
        final currentLesson = findLessonById(course, widget.lessonId);

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
              return VideoLessonPaywall(lesson: currentLesson);
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
                  PlayerSwitchButton(
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
          loading: () => const AppSkeleton(child: VideoPlayerSkeleton()),
          error: (e, _) => AppScreen(
            child: Center(
              child: Text(AppLocalizations.of(context)!.errorLoading(e.toString())),
            ),
          ),
        );
      },
      loading: () => const AppSkeleton(child: VideoPlayerSkeleton()),
      error: (e, _) => AppScreen(
        child: Center(
          child: Text(AppLocalizations.of(context)!.errorLoading(e.toString())),
        ),
      ),
    );
  }
}
