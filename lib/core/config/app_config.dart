/// Global application configuration and feature toggles.
class AppConfig {
  /// Toggle for Firebase Cloud Messaging.
  /// Set to false if FCM is not yet configured on the backend/device.
  static const bool fcmEnabled = true;

  /// Default timeout for remote network operations.
  static const Duration networkTimeout = Duration(seconds: 5);

  // ── Proxy Video Player ───────────────────────────────────────────────────
  // عنوان خادم Next.js الوسيط — غيّره فقط عند النشر في Production
  // الابعاد الافقية  980:660 و العمودية 560:740
  /// Production: Vercel Proxy
  // todo add to .env file for security
  static const String proxyBase = 'https://youtube-proxy-roan.vercel.app';

  // Production — فكّ التعليق وأضف عنوانك الفعلي:
  // static const String proxyBase = 'https://your-admin-domain.com';

  /// بناء رابط الـ Proxy لمعرّف الفيديو المُعطى
  static String buildVideoUrl(String videoId) =>
      '$proxyBase/api/video?videoId=$videoId';

  //https://youtube-proxy-roan.vercel.app/api/video?videoId=2-nQ1zKx_o4
  //https://your-admin-domain.com/api/video?videoId=2-nQ1zKx_o4
}
