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
/// - كل نسخة من الـ widget تُولّد [_viewId] فريدًا بالوقت لتجنّب
///   تعارض `platformViewRegistry`.
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
  /// معرّف فريد لكل نسخة — يمنع تسجيل نفس viewId مرتين
  late final String _viewId;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _viewId =
        'yt-proxy-${widget.videoId}-${DateTime.now().millisecondsSinceEpoch}';
    final url = AppConfig.buildVideoUrl(widget.videoId);

    if (kIsWeb) {
      // registerIframe → web: dart:html + platformViewRegistry
      //                → mobile: no-op stub
      registerIframe(_viewId, url);
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
