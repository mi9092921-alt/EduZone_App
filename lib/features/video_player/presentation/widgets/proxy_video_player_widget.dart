import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/app_config.dart';
import 'src/iframe_registrar.dart'; // conditional: web → dart:html, mobile → stub

/// مشغّل الفيديو عبر خادم Next.js الوسيط.
///
/// على **Flutter Web**: يُسجّل iframe في platformViewRegistry ويعرضه بـ [HtmlElementView].
/// على **Android / iOS**: يُعرض placeholder نصي (dart:html غير متاح).
///
/// ### مثال الاستخدام
/// ```dart
/// ProxyVideoPlayerWidget(videoId: 'yLOM8R6lbzg')
/// ```
///
/// ### ملاحظات
/// - [_viewId] مبني على [videoId] فقط (وليس بختم زمني لكل نسخة)، بحيث تُعاد
///   القيمة نفسها عند زيارة نفس الدرس مرة أخرى ويُعاد استخدام تسجيل
///   `platformViewRegistry` بدل تسجيله من جديد في كل مرة (انظر التعليق على
///   `_registeredViewIds`).
/// - [aspectRatio] افتراضيه 16/11 ويتوافق مع نافذة 984×670.
class ProxyVideoPlayerWidget extends StatefulWidget {
  final String videoId;

  /// نسبة العرض إلى الارتفاع (الافتراضي 16:11 = 984×553 على شاشة 984 بكسل)
  final double aspectRatio;

  const ProxyVideoPlayerWidget({
    super.key,
    required this.videoId,
    this.aspectRatio = 1.4848,
  });

  @override
  State<ProxyVideoPlayerWidget> createState() => _ProxyVideoPlayerWidgetState();
}

class _ProxyVideoPlayerWidgetState extends State<ProxyVideoPlayerWidget> {
  /// Tracks which viewIds have already been registered with dart:ui_web's
  /// `platformViewRegistry` for the lifetime of this app/tab.
  ///
  /// Section 20 (unbounded caches / navigation-leak hazard): Flutter Web
  /// exposes no API to *unregister* a view factory once registered. The
  /// previous implementation suffixed [_viewId] with
  /// `DateTime.now().millisecondsSinceEpoch` specifically so each new
  /// widget instance wouldn't collide with an existing registration — but
  /// that means every single navigation to a video screen (Home -> Course
  /// -> Video -> back, repeated) permanently grows this registry with no
  /// upper bound for as long as the tab stays open (see M37/M39
  /// "Navigation/Long-Session Leak Tests").
  ///
  /// Keying the id by `videoId` instead and registering each distinct
  /// video's factory only once caps growth at "one entry per distinct
  /// video opened this session" — and is also the idiomatic way to use
  /// `platformViewRegistry`: the registered `viewType` is a reusable
  /// factory, while `HtmlElementView` instances (and the DOM element the
  /// factory callback creates) are per-instantiation. Re-registering per
  /// widget instance was never necessary to get a fresh DOM element.
  static final Set<String> _registeredViewIds = {};

  /// معرّف الفيديو نفسه — لا يتغيّر بين عمليات إعادة الزيارة لنفس الدرس،
  /// فيسمح بإعادة استخدام تسجيل platformViewRegistry بدل تسجيله من جديد.
  late final String _viewId;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _viewId = 'yt-proxy-${widget.videoId}';
    final url = AppConfig.buildVideoUrl(widget.videoId);

    if (kIsWeb) {
      // registerIframe → web: dart:html + platformViewRegistry
      //                → mobile: no-op stub
      // Guarded so repeat visits to the same lesson reuse the existing
      // factory instead of growing the registry or throwing "factory
      // already registered for viewId".
      if (_registeredViewIds.add(_viewId)) {
        registerIframe(_viewId, url);
      }
    } else {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: _webViewController != null
            ? WebViewWidget(controller: _webViewController!)
            : const Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}
