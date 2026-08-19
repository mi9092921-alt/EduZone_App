import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../core/network/supabase_client.dart';
import '../../../../../core/utils/device_info_helper.dart';
import '../../../../../design_system/design_system.dart';
import '../../../../../shared/cross_feature/courses_shared.dart';
import '../../../../../shared/utils/error_handler.dart';
import '../../../application/providers/video_provider.dart';
import 'modern_player_error_overlay.dart';
import 'modern_player_fullscreen_exit_button.dart';
import 'modern_player_html.dart';
import 'modern_player_youtube_id.dart';

/// Strict shape of a real YouTube video id -- see the SECURITY
/// (AUTH/WEBVIEW-01) note on [_ModernPlayerWrapperState._switchVideo].
final RegExp _safeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Modern WebView-based YouTube video player with cleanup loops to remove
/// branding.
///
/// Structure note: WebView lifecycle (creation, JS bridge, message
/// handling, dynamic user-agent detection, video switching without a
/// reload) stays in this file — it's one cohesive unit driven by
/// `setState`/`mounted`/a native `InAppWebViewController`, and (like the
/// other split player wrappers) minimizing behavioral risk here matters
/// more than file length. The HTML/JS document builder, YouTube-id
/// extraction, and the small presentational pieces (error overlay,
/// fullscreen-exit button) have been extracted into sibling files in this
/// folder — each independently testable with no dependency on
/// `InAppWebViewController` or this State class.
class ModernPlayerWrapper extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const ModernPlayerWrapper({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.isFullScreen,
    required this.isVertical,
    required this.onToggleFullScreen,
  });

  @override
  ConsumerState<ModernPlayerWrapper> createState() => _ModernPlayerWrapperState();
}

class _ModernPlayerWrapperState extends ConsumerState<ModernPlayerWrapper>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey _webViewKey = GlobalKey();

  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  int _errorCode = 0;
  String _dynamicUA = '';
  late String _platform;
  bool _logged = false;
  String? _lastVideoId;
  String? _pendingVideoId;

  @override
  void initState() {
    super.initState();
    _platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios');
    _initUA();
  }

  @override
  void didUpdateWidget(covariant ModernPlayerWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      _logged = false;
    }
  }

  @override
  void dispose() {
    try {
      _webViewController?.evaluateJavascript(source: '''
        try { if (timerId) clearInterval(timerId); } catch(_) {}
        try { if (cleanupInterval) clearInterval(cleanupInterval); } catch(_) {}
      ''');
    } catch (_) {}

    _webViewController = null;
    super.dispose();
  }

  // ─── Dynamic User-Agent ──────────────────────────────────────────────────────

  Future<void> _initUA() async {
    if (kIsWeb) {
      _dynamicUA =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    } else {
      try {
        final ua = await InAppWebViewController.getDefaultUserAgent();
        if (ua.isNotEmpty) {
          var fixed = ua;
          if (Platform.isAndroid) {
            fixed = fixed.replaceAll('; wv', '').replaceAll(RegExp(r'Version/\d+\.\d+\s*'), '');
          } else if (Platform.isIOS && !fixed.contains('Safari') && fixed.contains('Mobile')) {
            fixed = '$fixed Safari/604.1';
          }
          _dynamicUA = fixed;
        }
      } catch (_) {}
    }

    if (_dynamicUA.isEmpty) {
      _dynamicUA = (!kIsWeb && Platform.isIOS)
          ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1'
          : 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.6367.82 Mobile Safari/537.36';
    }

    if (mounted) setState(() {});
  }

  // ─── Activity Logging ────────────────────────────────────────────────────────

  Future<void> _logLessonStarted() async {
    if (_logged) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc('log_activity_async', params: {
        'p_user_id': userId,
        'p_type': 'lesson_started',
        'p_details': {
          'course_id': widget.courseId,
          'lesson_id': widget.lessonId,
          'player': 'modern_v2',
          'device_platform': DeviceInfoHelper.platform,
        },
      });
      _logged = true;
    } catch (_) {}
  }

  // ─── Switch video without reloading WebView ──────────────────────────────────

  void _switchVideo(String videoId) {
    if (_lastVideoId == videoId) return;

    // SECURITY (AUTH/WEBVIEW-01): videoId is interpolated unescaped into
    // JS evaluated inside the WebView (`loadVideo('$videoId')`). It is
    // expected to already be validated by extractModernPlayerVideoId
    // upstream (in build()), which only ever hands this method null or a
    // strictly-shaped 11-char id. This is a last-resort guard in case a
    // future call site skips that validation -- fail safe by ignoring
    // the switch instead of executing an unvalidated string as JS.
    if (!_safeVideoIdPattern.hasMatch(videoId)) {
      return;
    }

    _lastVideoId = videoId;

    if (_webViewController != null) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      _webViewController!.evaluateJavascript(source: "loadVideo('$videoId');");
    } else {
      _pendingVideoId = videoId;
    }
  }

  // ─── Message handler ───────────────────────────────────────────────────────

  void _handleYTMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      if (decoded['PlayerError'] != null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorCode = (decoded['PlayerError'] as num).toInt();
        });
        _webViewController?.evaluateJavascript(source: 'if (timerId) { clearInterval(timerId); }');
      }

      if (decoded['Ready'] != null) {
        setState(() {
          _isLoading = false;
        });
      }

      // FIX: onReady only fires once for the lifetime of the player. When we
      // switch to a new lesson via loadVideo()/loadVideoById(), the player
      // never fires onReady again — only onStateChange. Without this, the
      // loading spinner set to true in _switchVideo() would never clear,
      // and the video would appear "stuck loading" after the first lesson.
      if (decoded['StateChange'] != null && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }

      if (decoded['VideoState'] != null) {
        final state = jsonDecode(decoded['VideoState'] as String);
        if (state is Map) {
          final current = double.tryParse(state['currentTime']?.toString() ?? '') ?? 0.0;
          final duration = double.tryParse(state['duration']?.toString() ?? '') ?? 0.0;

          if (duration > 0) {
            final pct = ((current / duration) * 100.0).clamp(0.0, 100.0);
            ref.read(videoProgressProvider(widget.courseId, widget.lessonId).notifier).updateProgress(
                  pct,
                  current.toInt(),
                  widget.courseId,
                  widget.lessonId,
                );
          }
        }
      }
    } catch (_) {}
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lessonContentAsync = ref.watch(lessonContentProvider(widget.lessonId));
    final ds = AppColors.of(context);

    return lessonContentAsync.when(
      data: (content) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _logLessonStarted());

        final videoId = extractModernPlayerVideoId(content.videoUrl);
        if (videoId == null || videoId.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.invalidVideoUrl,
              style: AppTextStyles.bodyMedium.copyWith(color: ds.error),
            ),
          );
        }

        if (_dynamicUA.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        // Switch video if lessonId changes
        if (_lastVideoId != null && _lastVideoId != videoId) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _switchVideo(videoId));
        }

        final playerWidget = AspectRatio(
          aspectRatio: widget.isVertical ? 9 / 16 : 16 / 9,
          child: Stack(
            children: [
              _buildWebView(videoId),
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 3,
                  ),
                ),
              if (_hasError)
                ModernPlayerErrorOverlay(
                  errorCode: _errorCode,
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });
                    _webViewController?.reload();
                  },
                ),
            ],
          ),
        );

        if (widget.isFullScreen) {
          return Stack(
            children: [
              Center(child: playerWidget),
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: ModernPlayerFullscreenExitButton(
                    tooltip: AppLocalizations.of(context)!.exitFullScreenButtonTooltip,
                    onPressed: widget.onToggleFullScreen,
                  ),
                ),
              ),
            ],
          );
        }

        return playerWidget;
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(ErrorHandler.getMessage(context, e)),
      ),
    );
  }

  // ─── WebView ─────────────────────────────────────────────────────────────────

  Widget _buildWebView(String videoId) {
    return InAppWebView(
      key: _webViewKey,
      initialData: InAppWebViewInitialData(
        data: buildModernPlayerHtml(
          videoId: videoId,
          platform: _platform,
          playerVars: '''{"autoplay": 1,"controls": 1,"rel": 0,"modestbranding": 1,"playsinline": 1,"fs": 0,"iv_load_policy": 3,"cc_load_policy": 0,"enablejsapi": 1,"origin": "https://www.youtube-nocookie.com","widget_referrer": "https://www.youtube-nocookie.com"}''',
        ),
        encoding: 'utf-8',
        baseUrl: WebUri('https://www.youtube-nocookie.com'),
      ),
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        supportZoom: false,
        userAgent: _dynamicUA,
        allowsLinkPreview: false,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        _lastVideoId = videoId;
        controller.addJavaScriptHandler(handlerName: 'onYTMessage', callback: (args) {
          if (args.isNotEmpty) {
            _handleYTMessage(args[0].toString());
          }
        });
        if (_pendingVideoId != null && _pendingVideoId != videoId) {
          final pending = _pendingVideoId!;
          _pendingVideoId = null;
          Future.microtask(() => _switchVideo(pending));
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('💬 [WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
      },
      onReceivedError: (controller, request, error) {
        debugPrint('🔴 [WebView Error] ${error.description} (Code: ${error.type})');
      },
      shouldOverrideUrlLoading: (controller, action) async {
        // SECURITY (AUTH/WEBVIEW-02): deny-by-default instead of
        // allow-by-default. This player only ever needs to stay on its
        // own origin (youtube-nocookie.com, set as initialData's
        // baseUrl) to render the IFrame player; it never needs to
        // navigate anywhere else. The previous policy explicitly
        // canceled navigation to the main youtube.com/youtu.be domains
        // (to stop the "watch on YouTube" chrome from escaping the
        // embed) but silently ALLOWed navigation to any other host --
        // meaning JS running inside this WebView (e.g. via any future
        // injection, or a compromised/malicious ad slot the IFrame API
        // itself may load) could navigate the WebView to an arbitrary
        // phishing/exfiltration URL and this widget would follow it.
        // Only the player's own origin, and the initial about:blank/
        // data-URL load, are allowed; everything else is canceled.
        final url = action.request.url?.toString() ?? '';
        if (url.isEmpty || url.startsWith('about:') || url.startsWith('data:')) {
          return NavigationActionPolicy.ALLOW;
        }
        if (url.startsWith('https://www.youtube-nocookie.com')) {
          return NavigationActionPolicy.ALLOW;
        }
        return NavigationActionPolicy.CANCEL;
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
