// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:ui_web' as ui;

/// تسجيل iframe في platformViewRegistry على منصة الويب
void registerIframe(String viewId, String proxyUrl) {
  ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
    // ── حاوية الـ wrapper ──────────────────────────────────────────────────
    final wrapper = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..style.position = 'relative'
      ..style.background = '#000';

    // منع القائمة السياقية (Right-click)
    wrapper.onContextMenu.listen((e) => e.preventDefault());

    // ── الـ iframe الفعلي ──────────────────────────────────────────────────
    final iframe = html.IFrameElement()
      ..src = proxyUrl
      ..style.border = 'none'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'accelerometer; autoplay; clipboard-write; '
          'encrypted-media; gyroscope; picture-in-picture'
      ..allowFullscreen = false;

    wrapper.append(iframe);
    return wrapper;
  });
}
