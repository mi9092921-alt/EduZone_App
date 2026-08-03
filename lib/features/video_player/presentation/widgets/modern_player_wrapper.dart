import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../providers/video_provider.dart';

// ─── HTML Builder ─────────────────────────────────────────────────────────────

String _buildPlayerHtml({
  required String videoId,
  required String platform,
  required String playerVars,
  String pointerEvents = 'inherit',
  String host = 'https://www.youtube-nocookie.com',
}) => '''

<!DOCTYPE html>

<html lang="en">
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
<style>
html {
  width: 100%;
  height: 100%;
  background-color: black;
  pointer-events: $pointerEvents;
  overflow: hidden;
}

body {margin: 0;width: 100%;height: 100%;background-color: black;pointer-events: inherit;overflow: hidden;}

.embed-container iframe,.embed-container object,.embed-container embed {position: absolute;top: 0;left: 0;width: 100% !important;height: 100% !important;pointer-events: inherit;}</style>

<title>Youtube Player</title>
</head>

<body>
<div class="embed-container">
<div id="ytPlayer"></div>
</div>

<script>
var tag = document.createElement("script");
tag.src = "https://www.youtube.com/iframe_api";
var firstScriptTag = document.getElementsByTagName("script")[0];
firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

var platform = "$platform";
var host = "$host";
var player;
var timerId;
var isPlayerReady = false;
var pendingVideoId = null;
var cleanupInterval = null;
var cleanupFailures = 0;

var messageQueue = [];
var bridgeReady = false;

function sendMessage(type, data) {
  var payload = {};
  try {
    payload[type] = data;
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === "function") {
      bridgeReady = true;
    }
    if (bridgeReady) {
      window.flutter_inappwebview.callHandler("onYTMessage", JSON.stringify(payload));
    } else {
      messageQueue.push(payload);
    }
  } catch (e) {
    try { messageQueue.push(payload); } catch (_) {}
  }
}

function flushQueue() {
  try {
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === "function") {
      bridgeReady = true;
      while (messageQueue.length > 0) {
        var payload = messageQueue.shift();
        window.flutter_inappwebview.callHandler("onYTMessage", JSON.stringify(payload));
      }
    }
  } catch (e) {}
}

window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
  flushQueue();
});

var flushInterval = setInterval(flushQueue, 100);

function handleFullScreenForMobilePlatform() {
  try {
    // Placeholder: add any mobile-specific fullscreen setup here.
    // Left as a safe no-op so onReady can continue executing.
  } catch (e) {}
}

function loadVideo(id) {
  if (isPlayerReady && player && typeof player.loadVideoById === "function") {
    player.loadVideoById(id);
  } else {
    pendingVideoId = id;
  }
}

function onYouTubeIframeAPIReady() {
  player = new YT.Player("ytPlayer", {
    host: host,
    videoId: "$videoId",
    playerVars: $playerVars,
    events: {
      onReady: function (event) {
        isPlayerReady = true;
        handleFullScreenForMobilePlatform();
        sendMessage('Ready', true);
        if (pendingVideoId) {
          player.loadVideoById(pendingVideoId);
          pendingVideoId = null;
        }
      },
      onStateChange: function (event) {
        clearInterval(timerId);
        sendMessage('StateChange', event.data);
        if (event.data == 1) {
          timerId = setInterval(function () {
            var state = {
              'currentTime': player.getCurrentTime(),
              'duration': player.getDuration(),
              'loadedFraction': player.getVideoLoadedFraction()
            };
            sendMessage('VideoState', JSON.stringify(state));
          }, 1000);
        }
      },
      onPlaybackQualityChange: function (event) {
        sendMessage('PlaybackQualityChange', event.data);
      },
      onPlaybackRateChange: function (event) {
        sendMessage('PlaybackRateChange', event.data);
      },
      onApiChange: function (event) {
        sendMessage('ApiChange', event.data);
      },
      onError: function (event) {
        sendMessage('PlayerError', event.data);
      },
      onAutoplayBlocked: function (event) {
        sendMessage('AutoplayBlocked', event.data);
      },
    },
  });
  player.setSize(window.innerWidth, window.innerHeight);

  if (cleanupInterval) {
    clearInterval(cleanupInterval);
  }

  cleanupInterval = setInterval(function() {
    try {
      var iframe = player.getIframe();

      if (!iframe || !iframe.contentWindow) {
        throw new Error('no-iframe-or-no-contentWindow');
      }

      var frameDoc = iframe.contentWindow.document;
      if (!frameDoc) return;

      cleanupFailures = 0;

      // ==============================
      // فلترة قائمة الإعدادات: حذف العناصر غير المرغوب فيها فقط
      // ==============================
      var blocklist = [
        "more", "أكثر", "خيارات",
        "report", "options", "بلاغ",
        "إضافية", "نسخ عنوان",

        "share", "مشاركة",
        "save", "حفظ",

        "playlist", "قائمة",
        "نسخ", "copy",

        "statistics", "إحصاءات", "إحصائيات",

        "download", "تنزيل",
        "clip", "مقطع",
        "thanks", "شكر",

        "shop", "تسوق",
        "not interested", "غير مهتم",

        "miniplayer", "مشغل مصغر",
        "watch later", "مشاهدة لاحقاً",
        "add to", "إضافة إلى"
      ];

      var items = frameDoc.getElementsByTagName("yt-list-item-view-model");
      for (var i = items.length - 1; i >= 0; i--) {
        var text = (items[i].innerText || items[i].textContent || '').trim().toLowerCase();
        var shouldRemove = blocklist.some(function(word) {
          return text.includes(word.toLowerCase());
        });
        if (shouldRemove) {
          items[i].remove();
        }
      }

      // ==============================
      // إزالة عناصر أخرى غير مرغوب فيها
      // ==============================
      var classSelectorsToRemove = [
        "fullscreen-action-menu",
        "fullscreen-controls style-recommendations-in-portrait",
        "ytp-show-cards-title",
        "ytmVideoInfoHost",
        "ytp-overflow-panel",
        "ytp-impression-link",
        "ytp-contextmenu",
        "ytp-pause-overlay",
        "videowall-endscreen",
        "ytp-youtube-button",
        "iv-branding",
        "ytp-ce-element",
        "ytp-chrome-top ytp-show-cards-title"
      ];

      for (var c = 0; c < classSelectorsToRemove.length; c++) {
        var els = frameDoc.getElementsByClassName(classSelectorsToRemove[c]);
        if (els.length > 0) {
          els[0].remove();
        }
      }

      var tagSelectorsToRemove = [
        "account-info-menu-item",
        "stable-volume-toggle",
        "switch-list-item-view-model"
      ];

      for (var t = 0; t < tagSelectorsToRemove.length; t++) {
        var tEls = frameDoc.getElementsByTagName(tagSelectorsToRemove[t]);
        if (tEls.length > 0) {
          tEls[0].remove();
        }
      }

    } catch (e) {
      try { cleanupFailures++; } catch (_) { cleanupFailures = cleanupFailures + 1; }
    }
  }, 40);

  window.onbeforeunload = function () {
    try { clearInterval(cleanupInterval); } catch (_) {}
    try { clearInterval(timerId); } catch (_) {}
  };
}
</script>

</body>
</html>
''';

// ─── Widget ───────────────────────────────────────────────────────────────────

/// Modern WebView-based YouTube video player with cleanup loops to remove branding.
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

  // ─── Video extraction ───────────────────────────────────────────────────────

  static final RegExp _youtubeIdPattern = RegExp(
    r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  );

  String? _extractVideoId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.length == 11 && !raw.contains('/')) return raw;

    final match = _youtubeIdPattern.firstMatch(raw);
    if (match != null) return match.group(1);

    return raw;
  }

  // ─── Switch video without reloading WebView ──────────────────────────────────

  void _switchVideo(String videoId) {
    if (_lastVideoId == videoId) return;
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

        final videoId = _extractVideoId(content.videoUrl);
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
              if (_hasError) _buildErrorOverlay(),
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── WebView ─────────────────────────────────────────────────────────────────

  Widget _buildWebView(String videoId) {
    return InAppWebView(
      key: _webViewKey,
      initialData: InAppWebViewInitialData(
        data: _buildPlayerHtml(
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
        final url = action.request.url?.toString() ?? '';
        if (url.startsWith('https://www.youtube') || url.startsWith('https://youtu.be') || url.startsWith('https://m.youtube')) {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  Widget _buildErrorOverlay() {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              'خطأ في تحميل الفيديو (كود: $_errorCode)',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _webViewController?.reload();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}