import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../../../../shared/utils/error_handler.dart';
import 'proxy_video_player_widget.dart';

class ProxyPlayerWrapper extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const ProxyPlayerWrapper({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.isFullScreen,
    required this.isVertical,
    required this.onToggleFullScreen,
  });

  @override
  ConsumerState<ProxyPlayerWrapper> createState() => _ProxyPlayerWrapperState();
}

class _ProxyPlayerWrapperState extends ConsumerState<ProxyPlayerWrapper> {
  bool _logged = false;

  /// Best-effort analytics ping: failure here must never block or
  /// interrupt playback (see catch block below). Previously had no
  /// timeout, so a stalled connection could leave this hanging
  /// indefinitely despite being written as fire-and-forget. See Section
  /// 13 ("Networking Reliability") of the project instructions.
  Future<void> _logLessonStarted() async {
    if (_logged) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc(
        'log_activity_async',
        params: {
          'p_user_id': userId,
          'p_type': 'lesson_started',
          'p_details': {
            'course_id': widget.courseId,
            'lesson_id': widget.lessonId,
            'player': 'proxy',
            'device_platform': DeviceInfoHelper.platform,
          },
        },
      ).timeout(NetworkConfig.telemetryTimeout);
      _logged = true;
    } catch (_) {
      // Best-effort analytics ping: failure here must never block or
      // interrupt playback, and there is nothing actionable for the user
      // to do about a dropped activity-log call, so it is intentionally
      // swallowed rather than surfaced.
    }
  }

  String? _extractVideoId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host.contains('youtube')) {
      return uri.queryParameters['v'] ??
          (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : raw);
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final lessonContentAsync = ref.watch(
      lessonContentProvider(widget.lessonId),
    );
    final ds = AppColors.of(context);

    return lessonContentAsync.when(
      data: (content) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _logLessonStarted(),
        );

        final videoId = _extractVideoId(content.videoUrl);
        if (videoId == null || videoId.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.invalidVideoUrl,
              style: AppTextStyles.bodyMedium.copyWith(color: ds.error),
            ),
          );
        }

        final playerWidget = ProxyVideoPlayerWidget(
          videoId: videoId,
          aspectRatio: widget.isVertical ? 9 / 16 : 16 / 9,
        );

        if (widget.isFullScreen) {
          return Stack(
            children: [
              Center(child: playerWidget),
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: AppRadius.xsBorder,
                    ),
                    child: AppIconButton(
                      icon: Icons.fullscreen_exit_rounded,
                      color: Colors.white,
                      iconSize: 28,
                      semanticLabel: AppLocalizations.of(context)!.exitFullScreenButtonTooltip,
                      onPressed: widget.onToggleFullScreen,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return playerWidget;
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(ErrorHandler.getMessage(context, e)),
      ),
    );
  }
}
