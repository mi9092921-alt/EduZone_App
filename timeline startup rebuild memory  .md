
 شغّل الأوامر دي وترجعلي المخرجات نصًا (أو ملفات JSON للـtimeline)،   بناءً على أدلة حقيقية بدل تخمين:

powershell

 
flutter --version
flutter pub get
flutter analyze
flutter test

flutter build appbundle --analyze-size --target-platform android-arm64

وللقياس الفعلي (startup/rebuild/memory):

powershell

flutter run --profile

وبعدها في DevTools (هيفتح تلقائيًا رابط): Timeline لأول frame، Performance overlay أثناء scroll على Discover/Home، Memory tab أثناء فتح/إغلاق فيديو 10-15 مرة (M37 leak test).