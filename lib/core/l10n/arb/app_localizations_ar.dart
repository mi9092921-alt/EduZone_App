// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'EduZone';

  @override
  String get welcome => 'أهلاً بك';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'الوصول إلى رحلتك التعليمية';

  @override
  String get emailHint => 'البريد الإلكتروني';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get homeTab => 'الرئيسية';

  @override
  String get discoverTab => 'اكتشف';

  @override
  String get coursesTab => 'الكورسات';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get sectionsLabel => 'أقسام';

  @override
  String get todoTab => 'مهامي';

  @override
  String get profileTab => 'حسابي';

  @override
  String get errorNetwork => 'لا يوجد اتصال بالإنترنت.';

  @override
  String get errorAuth => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorEmailNotConfirmed =>
      'يرجى تأكيد بريدك الإلكتروني قبل تسجيل الدخول.';

  @override
  String get errorLocked => 'تم قفل الحساب بسبب محاولات فاشلة متعددة.';

  @override
  String get errorBanned => 'لقد تم حظر حسابك.';

  @override
  String get errorSuspended => 'حسابك معلق مؤقتاً.';

  @override
  String get errorMaintenance => 'النظام تحت الصيانة. يرجى التحقق لاحقاً.';

  @override
  String get errorEmulatorBlocked => 'لا يمكن تسجيل الدخول من المحاكي.';

  @override
  String errorRateLimit(int minutes) {
    return 'محاولات كثيرة جداً، انتظر $minutes دقائق.';
  }

  @override
  String get errorMaxDevices => 'تم الوصول للحد الأقصى للأجهزة (جهاز واحد).';

  @override
  String get errorDeviceBound => 'هذا الجهاز مسجل لحساب آخر.';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get lockedScreenTitle => 'الحساب مقفل';

  @override
  String get lockedScreenMsg =>
      'تم قفل حسابك لأسباب أمنية. يرجى الاتصال بالدعم لإلغاء القفل.';

  @override
  String get lockedScreenContactBtn => 'اتصل بالدعم';

  @override
  String get bannedScreenTitle => 'الحساب محظور';

  @override
  String get bannedScreenMsg =>
      'تم حظر هذا الحساب نهائياً من منصة EduZone بسبب انتهاك شروط الخدمة.';

  @override
  String get bannedScreenAppeal =>
      'إذا كنت تعتقد أن هذا خطأ، يمكنك تقديم التماس عبر البريد: appeals@eduzone.com';

  @override
  String get suspendedScreenTitle => 'الحساب معلق';

  @override
  String get suspendedScreenMsg =>
      'تم تعليق وصولك مؤقتاً. يرجى مراجعة بريدك الإلكتروني لمزيد من التفاصيل.';

  @override
  String get suspendedScreenCheckStatusBtn => 'تحقق من الحالة';

  @override
  String get maintenanceScreenTitle => 'تحت الصيانة';

  @override
  String get maintenanceScreenMsg =>
      'نقوم حالياً بإجراء صيانة دورية لتحسين خدماتنا. سنعود قريباً!';

  @override
  String get maintenanceScreenEstTime => 'الوقت المقدر: 15 دقيقة';

  @override
  String maintenanceScreenEndTime(String time) {
    return 'وقت الانتهاء المتوقع: $time';
  }

  @override
  String statusReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String statusUntil(String time) {
    return 'حتى: $time';
  }

  @override
  String welcome_user(String firstName) {
    return 'أهلاً بك، $firstName 👋';
  }

  @override
  String get continue_learning => 'متابعة التعلم';

  @override
  String get recent_courses => 'الكورسات الأخيرة';

  @override
  String get today_todos => 'مهام اليوم';

  @override
  String get no_recent_courses => 'لا توجد كورسات أخيرة.';

  @override
  String get no_recent_todos => 'لا توجد مهام اليوم.';

  @override
  String get no_courses_available => 'لا توجد كورسات متاحة.';

  @override
  String get see_all => 'عرض الكل';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات';

  @override
  String get lessonNotFound => 'الدرس غير موجود';

  @override
  String get enrollmentRequired => 'الاشتراك مطلوب';

  @override
  String get enrollToAccessLesson =>
      'يرجى الاشتراك في هذه الدورة للوصول إلى هذا الدرس ومحتواه الكامل.';

  @override
  String get viewEnrollmentOptions => 'عرض خيارات الاشتراك';

  @override
  String get chooseVideoPlayer => 'اختر مشغل الفيديو';

  @override
  String get youtubePlayer => 'مشغل YouTube';

  @override
  String get youtubePlayerSubtitle => 'المشغل القياسي في Flutter';

  @override
  String get modernPlayer => 'المشغل الحديث';

  @override
  String get modernPlayerSubtitle =>
      'تجربة WebView مع إزالة العناصر غير الضرورية';

  @override
  String get directPlayer => 'المشغل المباشر';

  @override
  String get directPlayerSubtitle => 'تشغيل مباشر بجودة عالية بدون WebView';

  @override
  String get normalSpeed => 'طبيعية';

  @override
  String get retryLoading => 'إعادة المحاولة';

  @override
  String get checkInternetConnection =>
      'تحقق من اتصالك بالإنترنت وأعد المحاولة';

  @override
  String get serverError => 'حدث خطأ غير متوقع في الخادم';

  @override
  String get videoParseError =>
      'خطأ في بيانات الفيديو. حاول مجدداً أو تواصل مع الدعم الفني.';

  @override
  String get autoQuality => 'تلقائي';

  @override
  String get invalidVideoUrl => 'رابط الفيديو غير صالح';

  @override
  String get markAsDone => 'تحديد كمكتمل';

  @override
  String get completed => 'مكتمل';

  @override
  String errorLoading(String message) {
    return 'خطأ: $message';
  }

  @override
  String get tasksTitle => 'مهامي';

  @override
  String allTasks(int count) {
    return 'الكل ($count)';
  }

  @override
  String pendingTasks(int count) {
    return 'قيد التنفيذ ($count)';
  }

  @override
  String completedTasks(int count) {
    return 'المكتملة ($count)';
  }

  @override
  String get noTasks => 'لم يتم العثور على مهام';

  @override
  String get addTask => 'إضافة مهمة جديدة';

  @override
  String get editTask => 'تعديل المهمة';

  @override
  String get deleteTask => 'حذف المهمة';

  @override
  String get confirmDeleteTitle => 'تأكيد الحذف';

  @override
  String get confirmDeleteMsg =>
      'هل أنت متأكد من حذف هذه المهمة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get undo => 'تراجع';

  @override
  String get cancel => 'إلغاء';

  @override
  String get taskTitleHint => 'عنوان المهمة';

  @override
  String get taskDescHint => 'الوصف (اختياري)';

  @override
  String get taskPriority => 'الأولوية';

  @override
  String get priorityNormal => 'عادي';

  @override
  String get priorityMedium => 'متوسط';

  @override
  String get priorityHigh => 'مرتفع';

  @override
  String get dueDateLabel => 'تاريخ الاستحقاق';

  @override
  String get addBtn => 'إضافة';

  @override
  String get editButton => 'تعديل';

  @override
  String get deleteButton => 'حذف';

  @override
  String get taskAdded => 'تمت إضافة المهمة بنجاح';

  @override
  String get taskUpdated => 'تم تحديث المهمة بنجاح';

  @override
  String get taskDeleted => 'تم حذف المهمة بنجاح';

  @override
  String overdueLabel(String time) {
    return 'متأخر: $time';
  }

  @override
  String dueLabel(String time) {
    return 'موعدنا: $time';
  }

  @override
  String minCount(int count) {
    return '$count دقيقة';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count درس',
      many: '$count درسًا',
      few: '$count دروس',
      two: 'درسان',
      one: 'درس واحد',
      zero: 'لا توجد دروس',
    );
    return '$_temp0';
  }

  @override
  String get noContentAvailable => 'لا يوجد محتوى متاح.';

  @override
  String get searchCourses => 'ابحث عن الكورسات';

  @override
  String get failedToLoadCourses => 'فشل تحميل الكورسات. اسحب للتحديث.';

  @override
  String get generalCategory => 'عام';

  @override
  String get errorLoadingTasks => 'خطأ في تحميل المهام';

  @override
  String get errorPasswordTooShort =>
      'يجب أن تكون كلمة المرور 8 أحرف على الأقل';

  @override
  String get levelBeginner => 'مبتدئ';

  @override
  String get levelIntermediate => 'متوسط';

  @override
  String get levelAdvanced => 'متقدم';

  @override
  String get closeButton => 'إغلاق';

  @override
  String get notEnrolledMsg => 'أنت غير مشترك في هذا الكورس.';

  @override
  String get courseProgress => 'تقدم الكورس';

  @override
  String get enrollmentSuspended => 'اشتراكك معلق.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get loggingOut => 'جاري تسجيل الخروج...';

  @override
  String get settings => 'الإعدادات';

  @override
  String get pushNotifications => 'إشعارات التطبيق';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'الاسم الأخير';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get deviceInfo => 'الجهاز';

  @override
  String get verifiedDevice => 'موثق';

  @override
  String get changeAvatar => 'تغيير الصورة';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get avatarUpdated => 'تم تحديث الصورة بنجاح';

  @override
  String get themeLabel => 'المظهر';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeSystem => 'النظام';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get logoutConfirmTitle => 'تأكيد تسجيل الخروج';

  @override
  String get logoutConfirmMsg =>
      'هل أنت متأكد من تسجيل الخروج؟ ستحتاج للدخول مرة أخرى.';

  @override
  String get contactSupport => 'موظف الدعم';

  @override
  String get noInternetBanner => 'لا يوجد اتصال بالإنترنت';

  @override
  String suspendedCountdown(int days, int hours, int minutes) {
    return 'الوقت المتبقي: $days يوم $hours ساعة $minutes دقيقة';
  }

  @override
  String maintenanceCountdown(int hours, int minutes) {
    return 'الوقت المتبقي المقدر: $hours ساعة $minutes دقيقة';
  }

  @override
  String get supportAndInfo => 'الدعم والمعلومات';

  @override
  String get helpAndSupport => 'المساعدة والدعم';

  @override
  String get followUs => 'تابعنا';

  @override
  String get termsAndConditions => 'الشروط والأحكام';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsContent =>
      'باستخدامك لمنصة EduZone، فإنك توافق على الالتزام بجميع الشروط والأحكام الموضحة في هذه الاتفاقية. تم تصميم EduZone لتوفير خدمات تعليمية رقمية عالية الجودة مدعومة بالتقنيات الحديثة. يتم تقديم جميع المحتويات \"كما هي\" دون أي ضمانات صريحة أو ضمنية فيما يتعلق بالدقة أو الاكتمال. يطلب من المستخدمين استخدام المنصة بطريقة قانونية وأخلاقية.';

  @override
  String get privacyContent =>
      'في EduZone، نضع أعلى أولوية لحماية خصوصية المستخدم وبياناته الشخصية. نجمع فقط المعلومات الضرورية المطلوبة لتحسين جودة خدماتنا التعليمية، مثل تفاصيل التسجيل ونشاط الاستخدام. نلتزم بعدم بيع أو مشاركة بيانات المستخدم مع أطراف ثالثة دون موافقة صريحة، إلا ما يقتضيه القانون.';

  @override
  String get about => 'حول التطبيق';

  @override
  String get agreeToTerms => 'أوافق على الشروط والأحكام وسياسة الخصوصية';

  @override
  String get agreeToTermsPrefix => 'أوافق على ';

  @override
  String get agreeToTermsMiddle => ' و';

  @override
  String get agreeToTermsSuffix => '';

  @override
  String get agreeToTermsError => 'يجب الموافقة على الشروط والأحكام للمتابعة';

  @override
  String get errorInvalidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String lastUpdated(String date) {
    return 'آخر تحديث: $date';
  }

  @override
  String copyright(String year) {
    return '© $year منصة EduZone';
  }

  @override
  String get errorLinkUnavailable => 'الرابط غير متاح';

  @override
  String get modernLearningPlatform => 'منصة تعليمية حديثة للطلاب والمعلمين';

  @override
  String get ok => 'حسناً';

  @override
  String copyrightFull(String year) {
    return 'منصة EduZone © $year. جميع الحقوق محفوظة.';
  }

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get emailCopied => 'تم نسخ البريد الإلكتروني';

  @override
  String get defaultUserName => 'طالب';

  @override
  String get welcomeSubtitle => 'جاهز لتعزيز مهاراتك اليوم؟';

  @override
  String get permissionsHeader => 'أذونات التطبيق';

  @override
  String get locationPermission => 'الموقع الجغرافي';

  @override
  String get locationPermissionDescription =>
      'يُستخدم لتخصيص التجارب التعليمية القريبة والميزات المرتبطة بالموقع.';

  @override
  String get cameraPermission => 'الكاميرا';

  @override
  String get cameraPermissionDescription =>
      'يُستخدم عند التقاط صورة الملف الشخصي أو رفع مهام بصرية.';

  @override
  String get mediaPermission => 'الصور والملفات';

  @override
  String get mediaPermissionDescription =>
      'يُستخدم لرفع الملفات الدراسية والمرفقات والصور.';

  @override
  String get storagePermission => 'التخزين والكاميرا';

  @override
  String get notificationPermission => 'الإشعارات';

  @override
  String get notificationPermissionDescription =>
      'يُستخدم لتنبيهك بالمواعيد ونشاط الدورات والتحديثات المهمة.';

  @override
  String get permissionGranted => 'مسموح';

  @override
  String get permissionDenied => 'مرفوض';

  @override
  String get permissionPermanentlyDenied => 'معطل (من الإعدادات)';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get permDeniedTitle => 'الإذن مطلوب';

  @override
  String permDeniedMsg(String permission) {
    return 'تتطلب هذه الميزة الوصول إلى $permission. يرجى تفعيله يدوياً من إعدادات النظام.';
  }

  @override
  String get permActionOpenSettings => 'فتح الإعدادات';

  @override
  String get lessonsLabel => 'الدروس';

  @override
  String get courseDescriptionLabel => 'حول هذا الكورس';

  @override
  String get courseCurriculumLabel => 'محتوى الكورس';

  @override
  String get instructorLabel => 'المحاضر';

  @override
  String get priceLabel => 'السعر';

  @override
  String get freeLabel => 'مجاني';

  @override
  String get enrollNow => 'اشترك الآن';

  @override
  String get enrollmentComingSoon => 'ميزة الاشتراك ستتوفر قريباً!';

  @override
  String get resumeLearning => 'متابعة التعلم';

  @override
  String get allFilter => 'الكل';

  @override
  String get unreadFilter => 'غير مقروء';

  @override
  String get noUnreadNotifications => 'لا توجد تنبيهات جديدة!';

  @override
  String get notificationsEmptyDesc => 'سنخطرك عند حدوث شيء مهم.';

  @override
  String get daily_progress => 'التقدم اليومي';

  @override
  String get learning_time => 'وقت التعلم';

  @override
  String get streak_count => 'أيام الاستمرار';

  @override
  String get home_stats_title => 'إحصائياتك';

  @override
  String get explore_courses => 'اكتشف الكورسات';

  @override
  String get no_courses_desc =>
      'لم تبدأ أي كورس بعد. ما رأيك في اكتشاف شيء جديد اليوم؟';

  @override
  String get no_tasks_desc => 'أنت متفرغ تماماً! هل تريد التخطيط لمهمة جديدة؟';

  @override
  String get create_task => 'إنشاء مهمة';

  @override
  String get pendingLabel => 'قيد الانتظار';

  @override
  String get completeLabel => 'مكتمل';

  @override
  String get pendingFilter => 'قيد التنفيذ';

  @override
  String get completedFilter => 'المكتملة';

  @override
  String courseCardLabel(String title) {
    return 'كورس: $title';
  }

  @override
  String get courseCardHint => 'اضغط لعرض تفاصيل الكورس';

  @override
  String get progress => 'التقدم';

  @override
  String get paidPrice => 'مدفوع';

  @override
  String get featuredLabel => 'مميز';

  @override
  String get newStatusLabel => 'جديد';

  @override
  String get discoverTopPicks => 'اكتشف اختياراتنا لك';

  @override
  String get plus100Courses => '+100 كورس';

  @override
  String get exploreMore => 'استكشف المزيد';

  @override
  String get findLessons => 'ماذا تريد أن تتعلم اليوم؟';

  @override
  String get previewLabel => 'معاينة';

  @override
  String get videoLabel => 'فيديو';

  @override
  String get hours => 'ساعة';

  @override
  String get minutes => 'دقيقة';

  @override
  String get unknownInstructor => 'مدرب غير معروف';

  @override
  String get studentsLabel => 'طالب';

  @override
  String get whatYouWillLearn => 'ماذا ستتعلم';

  @override
  String get learningPoint1 =>
      'فهم الأساسيات والمفاهيم الرئيسية المتعلقة بالموضوع';

  @override
  String get learningPoint2 => 'تطبيق عملي خطوة بخطوة على مشاريع حقيقية';

  @override
  String get learningPoint3 => 'اكتساب المهارات المطلوبة في سوق العمل الحديث';

  @override
  String get coursePrerequisites => 'المتطلبات المسبقة';

  @override
  String get courseLanguage => 'اللغة';

  @override
  String get learningObjectives => 'أهداف التعلم';

  @override
  String get requirement1 => 'لا يُشترط وجود خبرة سابقة (مناسب للمبتدئين)';

  @override
  String get requirement2 => 'اتصال جيد بالإنترنت وجهاز كمبيوتر شخصي أو هاتف';

  @override
  String get reviewCourse => 'مراجعة الكورس';

  @override
  String get viewFullCourse => 'عرض الكورس كاملاً';

  @override
  String get enrolledSuccessfully => 'تم الاشتراك في الكورس بنجاح.';

  @override
  String get enrollmentFailed => 'فشل الاشتراك. يرجى المحاولة مرة أخرى.';

  @override
  String get fullAccessLabel => 'وصول كامل';

  @override
  String get permOpenSettingsManual =>
      'يرجى فتح الإعدادات → التطبيقات → EduZone → الأذونات لتفعيل الوصول';

  @override
  String get permOpenSettingsError =>
      'تعذر فتح الإعدادات. يرجى تفعيل الأذونات يدوياً.';

  @override
  String get noPreviewAvailable => 'لا يوجد فيديو معاينة متاح لهذا الكورس.';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get showMore => 'عرض المزيد';

  @override
  String get startNow => 'ابدأ الآن (مراجعة)';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get paymentNotAvailable =>
      'نظام الدفع غير متاح حالياً في هذا الإصدار. يمكنك طلب المراجعة وسيتم التواصل معك.';

  @override
  String get confirmRequest => 'تأكيد الطلب للمراجعة';

  @override
  String get requestReceived => 'تم استلام طلبك، سنقوم بمراجعته قريباً';

  @override
  String get forceUpdateTitle => 'تحديث إجباري مطلوب';

  @override
  String get forceUpdateMsg =>
      'يجب تحديث التطبيق للاستمرار في استخدام EduZone.';

  @override
  String get forceUpdateBtn => 'تحديث الآن';

  @override
  String get optionalUpdateTitle => 'تحديث جديد متاح';

  @override
  String get optionalUpdateBtn => 'تحديث الآن';

  @override
  String get optionalUpdateLater => 'لاحقاً';

  @override
  String get progressTitle => 'تقدمك';

  @override
  String lessonsCompleted(int completed, int total) {
    return '$completed/$total دروس';
  }

  @override
  String get courseCompleted => 'الكورس مكتمل! 🎉';

  @override
  String get overallProgress => 'التقدم العام';

  @override
  String get continueWatching => 'متابعة المشاهدة';

  @override
  String sectionProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String lastWatched(String time) {
    return 'آخر مشاهدة $time';
  }

  @override
  String get notStarted => 'لم تبدأ بعد';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusLocked => 'مقفل';

  @override
  String get statusSuspended => 'موقوف';

  @override
  String get statusBanned => 'محظور';

  @override
  String get statusInactive => 'غير نشط';

  @override
  String get statusMaintenance => 'صيانة';

  @override
  String get statusUnauthenticated => 'غير مسجل';

  @override
  String get statusAppLocked => 'التطبيق مقفل';

  @override
  String get statusUnrecognized => 'غير معروف';

  @override
  String get downloadNotFound => 'الملف غير موجود';

  @override
  String get downloadNotReady => 'الملف غير جاهز يرجى الانتظار';

  @override
  String get offlineModeLabel => 'وضع عدم الاتصال';

  @override
  String get errorGeneric => 'حدث خطأ';

  @override
  String get downloadsTitle => 'التنزيلات';

  @override
  String get downloadsEmpty => 'لا توجد تنزيلات بعد';

  @override
  String get downloadsEmptyHint => 'قم بتنزيل الدروس لمشاهدتها بدون إنترنت';

  @override
  String get downloadsError => 'خطأ في تحميل التنزيلات';

  @override
  String get downloadsRetry => 'إعادة المحاولة';

  @override
  String get downloadsCleanupTitle => 'تنظيف التنزيلات المنتهية';

  @override
  String get downloadsCleanupMsg =>
      'هل تريد حذف جميع التنزيلات المنتهية لتحرير مساحة التخزين؟';

  @override
  String get downloadsCleanup => 'تنظيف';

  @override
  String get downloadsDeleteTitle => 'حذف التنزيل';

  @override
  String get downloadsDeleteMsg => 'هل أنت متأكد من حذف هذا التنزيل؟';

  @override
  String get downloadsDeleteBtn => 'حذف';

  @override
  String get downloadsCancelBtn => 'إلغاء';

  @override
  String downloadsStorageUsed(String size) {
    return 'المساحة المستخدمة: $size م.ب';
  }

  @override
  String get downloadStatusPending => 'في الانتظار';

  @override
  String get downloadStatusDownloading => 'جاري التنزيل';

  @override
  String get downloadStatusPaused => 'متوقف مؤقتاً';

  @override
  String get downloadStatusCompleted => 'تم التنزيل';

  @override
  String get downloadStatusFailed => 'فشل التنزيل';

  @override
  String get downloadExpired => 'منتهي الصلاحية';

  @override
  String get downloadNeverExpires => 'لا ينتهي';

  @override
  String downloadExpiresInDays(int days) {
    return 'ينتهي خلال $days يوم';
  }

  @override
  String downloadExpiresInHours(int hours) {
    return 'ينتهي خلال $hours ساعة';
  }

  @override
  String get downloadExpiresSoon => 'ينتهي قريباً';

  @override
  String downloadCourseGroup(String courseId) {
    return 'كورس: $courseId';
  }

  @override
  String get downloadSelectQuality => 'اختر جودة الفيديو';

  @override
  String get downloadEstimatedSizes => 'حجم الملف التقريبي:';

  @override
  String get downloadPause => 'إيقاف مؤقت';

  @override
  String get downloadResume => 'استئناف';

  @override
  String get downloadCancel => 'إلغاء';

  @override
  String get downloadRetry => 'إعادة المحاولة';

  @override
  String get loadingOfflineLesson => 'جارٍ تجهيز الدرس للعرض…';

  @override
  String get offlinePlaybackError => 'تعذّر تشغيل الدرس بدون إنترنت.';

  @override
  String get playButtonLabel => 'تشغيل';

  @override
  String get pauseButtonTooltip => 'إيقاف مؤقت';

  @override
  String get fullScreenButtonTooltip => 'ملء الشاشة';

  @override
  String get exitFullScreenButtonTooltip => 'خروج من ملء الشاشة';

  @override
  String get settingsTooltip => 'إعدادات';

  @override
  String get audioSettingsTooltip => 'إعدادات الصوت';

  @override
  String get speedTooltip => 'سرعة التشغيل';

  @override
  String get volumeTooltip => 'مستوى الصوت';

  @override
  String get showControlsTooltip => 'إظهار/إخفاء عناصر التحكم';

  @override
  String get rewindButtonTooltip => 'إرجاع 10 ثوانٍ';

  @override
  String get fastForwardButtonTooltip => 'تقديم 10 ثوانٍ';

  @override
  String get toggleAspectRatioTooltip => 'تبديل أبعاد الفيديو';

  @override
  String get savedCoursesTitle => 'المحفوظات';

  @override
  String get savedCoursesEmptyMessage => 'لا توجد كورسات محفوظة';

  @override
  String get bookmarkFailed => 'فشل تحديث الإشارة المرجعية. حاول مرة أخرى.';

  @override
  String get bookmarkAdd => 'إضافة إلى المحفوظات';

  @override
  String get bookmarkRemove => 'إزالة من المحفوظات';

  @override
  String get downloadLesson => 'تنزيل الدرس';

  @override
  String get shareCourse => 'مشاركة الدورة';

  @override
  String get videoSeekBack => 'إرجاع 10 ثوانٍ';

  @override
  String get videoSeekForward => 'تقديم 10 ثوانٍ';

  @override
  String get videoPlay => 'تشغيل';

  @override
  String get videoPause => 'إيقاف مؤقت';

  @override
  String get videoMute => 'كتم الصوت';

  @override
  String get videoUnmute => 'إلغاء الكتم';

  @override
  String get passwordShow => 'إظهار كلمة المرور';

  @override
  String get passwordHide => 'إخفاء كلمة المرور';

  @override
  String get videoEnterFullscreen => 'تشغيل ملء الشاشة';

  @override
  String get videoExitFullscreen => 'إيقاف ملء الشاشة';

  @override
  String get videoOrientationPortrait => 'التبديل للوضع الرأسي';

  @override
  String get videoOrientationLandscape => 'التبديل للوضع الأفقي';

  @override
  String get videoSwitchPlayer => 'تبديل مشغّل الفيديو';

  @override
  String get navigateBack => 'رجوع';

  @override
  String lessonsProgress(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'درس',
      many: 'درسًا',
      few: 'دروس',
      two: 'درسان',
      one: 'درس واحد',
      zero: 'دروس',
    );
    return '$completed/$total $_temp0';
  }

  @override
  String downloadingTitle(String title) {
    return 'جاري تنزيل $title';
  }

  @override
  String downloadingProgress(String pct) {
    return 'تم اكتمال $pct%';
  }

  @override
  String get downloadingSubtitle => 'جاري التنزيل...';

  @override
  String get downloadCompleted => 'تم اكتمال التنزيل';

  @override
  String get downloadFailed => 'فشل التنزيل';

  @override
  String get loadingLessonData => 'جاري تحميل بيانات الدرس...';

  @override
  String get videoUrlError => 'فشل الحصول على رابط الفيديو';

  @override
  String get downloadStarting => 'جاري بدء التنزيل...';

  @override
  String downloadStartedSuccess(String quality) {
    return 'تم بدء تنزيل الجودة $quality بنجاح';
  }

  @override
  String downloadStartFailed(String error) {
    return 'فشل بدء التنزيل: $error';
  }

  @override
  String videoInfoFetchFailed(String error) {
    return 'فشل جلب خصائص الفيديو: $error';
  }

  @override
  String downloadActionFailed(String error) {
    return 'فشلت العملية: $error';
  }

  @override
  String get choosePlayer => 'اختر المشغل';

  @override
  String videoLoadErrorCode(int errorCode) {
    return 'خطأ في تحميل الفيديو (كود: $errorCode)';
  }

  @override
  String get taskInputHint => 'ما الذي يجب فعله؟';

  @override
  String get dismissOfflineNotice => 'إغلاق إشعار انقطاع الاتصال';
}
