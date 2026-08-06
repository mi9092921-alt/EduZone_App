/// Builds the HTML+JS document loaded into the WebView: a bare YouTube
/// IFrame Player API page, plus a bridge (`sendMessage`/`onYTMessage`) back
/// to Flutter, plus a polling cleanup loop that strips YouTube branding
/// elements (share/save/playlist/etc menu items, watermark, end-screen
/// cards) from the player chrome.
///
/// Pure function of its parameters — deterministic string output, no
/// widget/state dependency — so it moves out unchanged from the original
/// private `_buildPlayerHtml` and is now directly unit-testable (e.g.
/// asserting the video id, platform, and playerVars are correctly
/// interpolated into the generated script).
///
/// Renamed from `_buildPlayerHtml` (public now that it lives in its own
/// file) — no change to its implementation.
String buildModernPlayerHtml({
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
