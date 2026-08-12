// Conditional export facade:
// - على الويب        → تستخدم dart:html + dart:ui_web
// - على Android/iOS  → stub فارغ (no-op)
export 'iframe_registrar_stub.dart'
    if (dart.library.html) 'iframe_registrar_web.dart';
