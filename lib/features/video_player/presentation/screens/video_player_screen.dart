import 'dart:async';
import 'dart:math' as math;

import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/models/lesson_content.dart';
import '../../application/providers/video_provider.dart';
import '../widgets/lessons_sidebar.dart';
import 'video_player/lesson_lookup.dart';
import 'video_player/player_type.dart';
import 'video_player/video_lesson_paywall.dart';

export 'video_player/player_type.dart';

/// The player widget handed to [VideoPlayerScreen], built once per frame by
/// the route composition layer with the already-resolved lesson content.
typedef PlayerWidgetBuilder =
    Widget Function(
      BuildContext context,
      bool isFullScreen,
      VoidCallback toggleFullScreen,
      bool isVertical,
    );

/// Factory used by `app_router.dart` to bind the resolved lesson content
/// into the concrete player widget for the selected player type.
typedef VideoPlayerBuilderFactory =
    PlayerWidgetBuilder Function(
      String courseId,
      String lessonId,
      LessonContent content,
    );

// ─────────────────────────────────────────────────────────────────────────────
// مشغّل الدروس الموحّد (Universal Video Player Screen)
//
// يستقبل [playerBuilder] لبناء المشغّل المناسب،
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
// ─────────────────────────────────────────────────────────────────────────────

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;

  /// Resolved course + lesson content, passed down by the route builder in
  /// `app_router.dart` (which watches the courses providers) so this screen
  /// does not import courses feature internals. Loading and error states are
  /// handled by that route builder before this screen is constructed.
  final Course course;
  final LessonContent lessonContent;

  /// Backend-verified enrollment for [course], resolved by the route
  /// composition layer from the courses feature's `isEnrolledProvider`.
  final bool isEnrolled;
  final PlayerWidgetBuilder playerBuilder;

  /// Route-composition callback that preloads and navigates to another lesson.
  /// Optional to keep this screen usable with isolated/test player builders.
  final Future<void> Function(String lessonId)? onLessonTap;
  final PlayerType playerType;

  const VideoPlayerScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.course,
    required this.lessonContent,
    required this.isEnrolled,
    required this.playerBuilder,
    this.onLessonTap,
    this.playerType = PlayerType.youtube,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _isFullScreen = false;
  bool _isVertical = false;
  bool _isSwitchingLesson = false;

  // مفتاح ثابت (يُنشأ مرة واحدة فقط لكل درس) يحافظ على عنصر شجرة الـ widget
  // الخاص بالمشغّل عند انتقاله بين التخطيط العادي (داخل Column) ووضع ملء
  // الشاشة (body لـ Scaffold مختلف). بدون هذا المفتاح، فلاتر يتعامل مع
  // الانتقال كأنه widget جديد كليًا، فيُدمَّر الـ State (والـ controller
  // الداخلي للفيديو) ويُعاد إنشاؤه من الصفر — وهو ما يسبب إعادة تحميل
  // الفيديو من البداية عند الضغط على زر ملء الشاشة (وينطبق على كل المشغلات
  // الأربعة لأنها كلها تمر من هذه النقطة).
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Provider state must not be mutated while Flutter is mounting the
    // widget tree. Defer the monotonic server seed until the first frame;
    // this keeps the server-known progress protection without causing
    // "Tried to modify a provider while the widget tree was building".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedProgressFromServer();
    });
  }

  void _seedProgressFromServer() {
    // Phase 10 (progress-corruption fix): seed the progress notifier with
    // the SERVER-known progress for this lesson (embedded per-user in the
    // course outline the route layer resolved). Without this, re-opening a
    // completed/further-along lesson started the notifier at 0/false and
    // the first playback tick overwrote the server's higher progress —
    // the RPC's ON CONFLICT is last-writer-wins. Seeding only upgrades
    // (monotonic pct, sticky completion); see VideoProgress.seedFromServer.
    final lesson = findLessonById(widget.course, widget.lessonId);
    final progress = (lesson?.userProgress?.isNotEmpty ?? false)
        ? lesson!.userProgress!.first
        : null;
    if (progress != null) {
      ref
          .read(
            videoProgressProvider(widget.courseId, widget.lessonId).notifier,
          )
          .seedFromServer(
            progressPct: progress.progressPct,
            completed: progress.completed,
            watchTimeSec: progress.watchTimeSec,
          );
    }
  }

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

  Future<void> _handleLessonTap(String lessonId) async {
    final onLessonTap = widget.onLessonTap;
    if (_isSwitchingLesson ||
        lessonId == widget.lessonId ||
        onLessonTap == null) {
      return;
    }

    setState(() => _isSwitchingLesson = true);
    try {
      // The route layer preloads and validates the next lesson before it
      // replaces this page. Keeping the current player mounted during that
      // request prevents a transient RPC/network failure from replacing a
      // working lesson with an error page.
      await onLessonTap(lessonId);
    } finally {
      if (mounted) setState(() => _isSwitchingLesson = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final content = widget.lessonContent;
    final ds = AppColors.of(context);

    final currentLesson = findLessonById(course, widget.lessonId);

    if (currentLesson == null) {
      return AppScreen(
        appBar: AppBar(elevation: 0),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.lessonNotFound,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
          ),
        ),
      );
    }

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

    final videoState = ref.watch(
      videoProgressProvider(widget.courseId, widget.lessonId),
    );

    return AppScreen(
      scrollable: false,
      backgroundColor: _isFullScreen ? Colors.black : null,
      appBar: AppBar(
        elevation: _isFullScreen ? 0 : null,
        backgroundColor: _isFullScreen ? Colors.black : null,
        toolbarHeight: _isFullScreen ? 0 : kToolbarHeight,
        title: _isFullScreen
            ? null
            : Text(currentLesson.title, style: AppTextStyles.h3),
        // The in-player switch button was removed deliberately: its sheet
        // listed every player backend unconditionally and bypassed the
        // remote feature-flag kill switches that the lesson-tap choice
        // sheet (courses feature) honors. Player selection now happens
        // only through that gated sheet.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── مشغّل الفيديو (Injected) ───────────────────────────
          // Keep one stable flex slot for the platform-view-backed player in
          // both modes. Moving that subtree between two Scaffold bodies on a
          // fullscreen toggle can dirty Flutter's semantics tree.
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final maxHeight = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : MediaQuery.sizeOf(context).height;
                final naturalHeight = _isVertical
                    ? width * 16 / 9
                    : width * 9 / 16;
                final normalHeight = _isVertical
                    ? math.min(
                        naturalHeight,
                        MediaQuery.sizeOf(context).height * 0.52,
                      )
                    : naturalHeight;
                final height = _isFullScreen
                    ? maxHeight
                    : math.min(normalHeight, maxHeight);

                // The explicit finite size is required for the platform view
                // in fullscreen; SizedBox.expand inside the player cannot
                // resolve an unbounded loose-flex constraint safely.
                return SizedBox(
                  width: width,
                  height: height,
                  child: playerWidget,
                );
              },
            ),
          ),

          if (!_isFullScreen && videoState.progressPct > 0)
            LinearProgressIndicator(
              value: videoState.progressPct / 100,
              backgroundColor: ds.border,
              color: videoState.isCompleted ? ds.success : ds.primary,
              minHeight: 4,
            ),
          if (!_isFullScreen)
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
                        ? AppLocalizations.of(
                            context,
                          )!.videoOrientationLandscape
                        : AppLocalizations.of(
                            context,
                          )!.videoOrientationPortrait,
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
                    semanticLabel: AppLocalizations.of(
                      context,
                    )!.videoEnterFullscreen,
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
          if (!_isFullScreen) Divider(height: 1, color: ds.border),

          // ─── قائمة الدروس الجانبية ───────────────────────────────
          if (!_isFullScreen)
            Expanded(
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: _isSwitchingLesson,
                    child: LessonsSidebar(
                      course: course,
                      currentLessonId: widget.lessonId,
                      isEnrolled: widget.isEnrolled,
                      onLessonTap: (newId) =>
                          unawaited(_handleLessonTap(newId)),
                    ),
                  ),
                  if (_isSwitchingLesson)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black12,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
