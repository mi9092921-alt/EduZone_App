/// Global application configuration and feature toggles.
class AppConfig {
  /// Toggle for Firebase Cloud Messaging.
  /// Set to false if FCM is not yet configured on the backend/device.
  static const bool fcmEnabled = true;

  /// Default timeout for remote network operations.
  static const Duration networkTimeout = Duration(seconds: 5);

  // ── Proxy Video Player ───────────────────────────────────────────────────
  // عنوان خادم Next.js الوسيط — يُقرأ الآن من --dart-define-from-file
  // (PROXY_BASE_URL في .env / .env.staging / .env.prod)، مع الإبقاء على
  // نفس القيمة الحالية كـ default حتى لا يتغيّر أي سلوك لمن لا يملك
  // متغيّر البيئة هذا بعد. غيّره فعليًا عبر ملف الـ .env المناسب لكل
  // بيئة، وليس بتعديل هذا الملف مباشرة.
  // الابعاد الافقية  980:660 و العمودية 560:740
  static const String proxyBase = String.fromEnvironment(
    'PROXY_BASE_URL',
    defaultValue: 'https://youtube-proxy-roan.vercel.app',
  );

  /// بناء رابط الـ Proxy لمعرّف الفيديو المُعطى
  ///
  /// SECURITY: [videoId] is percent-encoded via [Uri.encodeQueryComponent]
  /// before being placed in the query string. Without this, a videoId
  /// containing `&`, `#`, or other URL-structural characters could
  /// inject additional query parameters or alter the URL the WebView
  /// navigates to instead of being treated as an opaque value.
  static String buildVideoUrl(String videoId) =>
      '$proxyBase/api/video?videoId=${Uri.encodeQueryComponent(videoId)}';

  //https://youtube-proxy-roan.vercel.app/api/video?videoId=2-nQ1zKx_o4
  //https://your-admin-domain.com/api/video?videoId=2-nQ1zKx_o4
}
