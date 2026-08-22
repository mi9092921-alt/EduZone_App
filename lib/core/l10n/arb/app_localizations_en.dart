// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EduZone';

  @override
  String get welcome => 'Welcome';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginSubtitle => 'Access your learning journey';

  @override
  String get emailHint => 'Email Address';

  @override
  String get passwordHint => 'Password';

  @override
  String get loginButton => 'Login';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get homeTab => 'Home';

  @override
  String get discoverTab => 'Discover';

  @override
  String get coursesTab => 'Courses';

  @override
  String get downloads => 'Downloads';

  @override
  String get sectionsLabel => 'sections';

  @override
  String get todoTab => 'To-Do';

  @override
  String get profileTab => 'Profile';

  @override
  String get errorNetwork => 'No internet connection.';

  @override
  String get errorAuth => 'Invalid email or password.';

  @override
  String get errorEmailNotConfirmed =>
      'Please confirm your email before signing in.';

  @override
  String get errorLocked =>
      'Account is locked due to multiple failed attempts.';

  @override
  String get errorBanned => 'Your account has been banned.';

  @override
  String get errorSuspended => 'Your account is temporarily suspended.';

  @override
  String get errorMaintenance =>
      'System is under maintenance. Please check back later.';

  @override
  String get errorEmulatorBlocked => 'Cannot sign in from an emulator.';

  @override
  String errorRateLimit(int minutes) {
    return 'Too many attempts, wait $minutes minutes.';
  }

  @override
  String get errorMaxDevices => 'Device limit reached (1 device).';

  @override
  String get errorDeviceBound => 'Device registered to another account.';

  @override
  String get retryButton => 'Retry';

  @override
  String get lockedScreenTitle => 'Account Locked';

  @override
  String get lockedScreenMsg =>
      'Your account has been locked for security reasons. Please contact support to unlock it.';

  @override
  String get lockedScreenContactBtn => 'Contact Support';

  @override
  String get bannedScreenTitle => 'Account Banned';

  @override
  String get bannedScreenMsg =>
      'This account has been permanently banned from EduZone due to violations of our Terms of Service.';

  @override
  String get bannedScreenAppeal =>
      'If you believe this is a mistake, you can appeal this decision by emailing appeals@eduzone.com';

  @override
  String get suspendedScreenTitle => 'Account Suspended';

  @override
  String get suspendedScreenMsg =>
      'Your access has been temporarily suspended. Please check your email for more details or contact your administrator.';

  @override
  String get suspendedScreenCheckStatusBtn => 'Check Status';

  @override
  String get maintenanceScreenTitle => 'Under Maintenance';

  @override
  String get maintenanceScreenMsg =>
      'We are currently performing scheduled maintenance to improve our services. We will be back shortly!';

  @override
  String get maintenanceScreenEstTime => 'Estimated time: 15 minutes';

  @override
  String maintenanceScreenEndTime(String time) {
    return 'Estimated end time: $time';
  }

  @override
  String statusReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String statusUntil(String time) {
    return 'Until: $time';
  }

  @override
  String welcome_user(String firstName) {
    return 'Welcome, $firstName 👋';
  }

  @override
  String get continue_learning => 'Continue Learning';

  @override
  String get recent_courses => 'Recent Courses';

  @override
  String get today_todos => 'Today\'s Tasks';

  @override
  String get no_recent_courses => 'No recent courses.';

  @override
  String get no_recent_todos => 'No tasks for today.';

  @override
  String get no_courses_available => 'No courses available.';

  @override
  String get see_all => 'See all';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get lessonNotFound => 'Lesson not found';

  @override
  String get enrollmentRequired => 'Enrollment Required';

  @override
  String get enrollToAccessLesson =>
      'Please enroll in this course to access this lesson and its full content.';

  @override
  String get viewEnrollmentOptions => 'View Enrollment Options';

  @override
  String get chooseVideoPlayer => 'Choose video player';

  @override
  String get youtubePlayer => 'YouTube Player';

  @override
  String get youtubePlayerSubtitle => 'Standard Flutter player';

  @override
  String get modernPlayer => 'Modern Player';

  @override
  String get modernPlayerSubtitle => 'WebView experience with UI cleanup';

  @override
  String get directPlayer => 'Direct Player';

  @override
  String get directPlayerSubtitle => 'High-quality playback without WebView';

  @override
  String get normalSpeed => 'Normal';

  @override
  String get retryLoading => 'Retry';

  @override
  String get checkInternetConnection =>
      'Check your internet connection and try again';

  @override
  String get serverError => 'Unexpected server error';

  @override
  String get videoParseError =>
      'Video data error. Please try again or contact support.';

  @override
  String get autoQuality => 'Auto';

  @override
  String get invalidVideoUrl => 'Invalid Video URL';

  @override
  String get markAsDone => 'Mark Done';

  @override
  String get completed => 'Completed';

  @override
  String errorLoading(String message) {
    return 'Error: $message';
  }

  @override
  String get tasksTitle => 'My Tasks';

  @override
  String allTasks(int count) {
    return 'All ($count)';
  }

  @override
  String pendingTasks(int count) {
    return 'Pending ($count)';
  }

  @override
  String completedTasks(int count) {
    return 'Completed ($count)';
  }

  @override
  String get noTasks => 'No tasks found';

  @override
  String get addTask => 'Add New Task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String get confirmDeleteTitle => 'Confirm Deletion';

  @override
  String get confirmDeleteMsg =>
      'Are you sure you want to delete this task? This action cannot be undone.';

  @override
  String get undo => 'Undo';

  @override
  String get cancel => 'Cancel';

  @override
  String get taskTitleHint => 'Task Title';

  @override
  String get taskDescHint => 'Description (Optional)';

  @override
  String get taskPriority => 'Priority';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get dueDateLabel => 'Due Date';

  @override
  String get addBtn => 'Add';

  @override
  String get editButton => 'Edit';

  @override
  String get deleteButton => 'Delete';

  @override
  String get taskAdded => 'Task added successfully';

  @override
  String get taskUpdated => 'Task updated successfully';

  @override
  String get taskDeleted => 'Task deleted successfully';

  @override
  String overdueLabel(String time) {
    return 'Overdue: $time';
  }

  @override
  String dueLabel(String time) {
    return 'Due: $time';
  }

  @override
  String minCount(int count) {
    return '$count min';
  }

  @override
  String lessonsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
      zero: 'No lessons',
    );
    return '$_temp0';
  }

  @override
  String get noContentAvailable => 'No content available.';

  @override
  String get searchCourses => 'Search Courses';

  @override
  String get failedToLoadCourses => 'Failed to load courses. Pull to refresh.';

  @override
  String get generalCategory => 'General';

  @override
  String get errorLoadingTasks => 'Error loading tasks';

  @override
  String get errorPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get levelBeginner => 'Beginner';

  @override
  String get levelIntermediate => 'Intermediate';

  @override
  String get levelAdvanced => 'Advanced';

  @override
  String get closeButton => 'Close';

  @override
  String get notEnrolledMsg => 'You are not enrolled in this course.';

  @override
  String get courseProgress => 'Course Progress';

  @override
  String get enrollmentSuspended => 'Your enrollment is suspended.';

  @override
  String get logout => 'Logout';

  @override
  String get loggingOut => 'Logging out...';

  @override
  String get settings => 'Settings';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get deviceInfo => 'Device';

  @override
  String get verifiedDevice => 'Verified';

  @override
  String get changeAvatar => 'Change Photo';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get avatarUpdated => 'Photo updated successfully';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get languageLabel => 'Language';

  @override
  String get logoutConfirmTitle => 'Confirm Logout';

  @override
  String get logoutConfirmMsg =>
      'Are you sure you want to log out? You will need to sign in again.';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get noInternetBanner => 'No internet connection';

  @override
  String suspendedCountdown(int days, int hours, int minutes) {
    return 'Time remaining: ${days}d ${hours}h ${minutes}m';
  }

  @override
  String maintenanceCountdown(int hours, int minutes) {
    return 'Estimated time remaining: ${hours}h ${minutes}m';
  }

  @override
  String get supportAndInfo => 'Support & Info';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get followUs => 'Follow Us';

  @override
  String get termsAndConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsContent =>
      'By using EduZone, you agree to comply with all the terms and conditions outlined in this agreement. EduZone is designed to provide high-quality digital educational services powered by modern technologies. All content is provided \"as is\" without any express or implied warranties regarding accuracy, completeness, or suitability for a particular purpose. Users are required to use the platform in a lawful and ethical manner and must not engage in any misuse, including but not limited to unauthorized access, attempts to breach system security, or the distribution of harmful or misleading content. EduZone reserves the right to modify or update these terms at any time without prior notice, and continued use of the platform constitutes acceptance of those changes. The platform administration also reserves the right to suspend or terminate user accounts in cases of violations or misuse, in order to protect the integrity of the system and other users.';

  @override
  String get privacyContent =>
      'At EduZone, we place the highest priority on protecting user privacy and personal data. We collect only the necessary information required to enhance the quality of our educational services, such as registration details, usage activity, and interactions within the platform. This data is used to improve user experience, personalize educational content, and optimize overall system performance. We are committed to not selling or sharing user data with third parties without explicit consent, except where required by law or to protect our legal rights. All data is stored using advanced security standards, including encryption and strict access controls, to safeguard against unauthorized access or data breaches. By using the platform, you agree to this privacy policy, while retaining the right to request access, modification, or deletion of your data in accordance with applicable policies.';

  @override
  String get about => 'About';

  @override
  String get agreeToTerms =>
      'I agree to the Terms & Conditions and Privacy Policy';

  @override
  String get agreeToTermsPrefix => 'I agree to the ';

  @override
  String get agreeToTermsMiddle => ' and ';

  @override
  String get agreeToTermsSuffix => '';

  @override
  String get agreeToTermsError =>
      'You must agree to the terms and conditions to continue';

  @override
  String get errorInvalidEmail => 'Please enter a valid email address';

  @override
  String lastUpdated(String date) {
    return 'Last Updated: $date';
  }

  @override
  String copyright(String year) {
    return '© $year EduZone Platform';
  }

  @override
  String get errorLinkUnavailable => 'Link unavailable';

  @override
  String get modernLearningPlatform =>
      'Modern learning platform for students and teachers';

  @override
  String get ok => 'OK';

  @override
  String copyrightFull(String year) {
    return 'EduZone Platform © $year. All rights reserved.';
  }

  @override
  String versionLabel(String version) {
    return 'v$version';
  }

  @override
  String get emailCopied => 'Email copied to clipboard';

  @override
  String get defaultUserName => 'Student';

  @override
  String get welcomeSubtitle => 'Ready to boost your skills today?';

  @override
  String get permissionsHeader => 'App Permissions';

  @override
  String get locationPermission => 'Location';

  @override
  String get locationPermissionDescription =>
      'Used to personalize nearby learning experiences and location-aware features.';

  @override
  String get cameraPermission => 'Camera';

  @override
  String get cameraPermissionDescription =>
      'Used when you capture a profile photo or submit visual course work.';

  @override
  String get mediaPermission => 'Photos & Files';

  @override
  String get mediaPermissionDescription =>
      'Used when you upload study materials, attachments, and profile images.';

  @override
  String get storagePermission => 'Storage & Camera';

  @override
  String get notificationPermission => 'Notifications';

  @override
  String get notificationPermissionDescription =>
      'Used to alert you about deadlines, course activity, and important updates.';

  @override
  String get permissionGranted => 'Granted';

  @override
  String get permissionDenied => 'Denied';

  @override
  String get permissionPermanentlyDenied => 'Disabled (Settings)';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get permDeniedTitle => 'Permission Required';

  @override
  String permDeniedMsg(String permission) {
    return 'This feature requires $permission access. Since it was permanently denied, please enable it manually in the system settings.';
  }

  @override
  String get permActionOpenSettings => 'Open Settings';

  @override
  String get lessonsLabel => 'Lessons';

  @override
  String get courseDescriptionLabel => 'About this Course';

  @override
  String get courseCurriculumLabel => 'Course Content';

  @override
  String get instructorLabel => 'Instructor';

  @override
  String get priceLabel => 'Price';

  @override
  String get freeLabel => 'Free';

  @override
  String get enrollNow => 'Enroll Now';

  @override
  String get enrollmentComingSoon => 'Enrollment functionality is coming soon!';

  @override
  String get resumeLearning => 'Continue Learning';

  @override
  String get allFilter => 'All';

  @override
  String get unreadFilter => 'Unread';

  @override
  String get noUnreadNotifications => 'All caught up!';

  @override
  String get notificationsEmptyDesc =>
      'We will notify you when something important happens.';

  @override
  String get daily_progress => 'Daily Progress';

  @override
  String get learning_time => 'Learning Time';

  @override
  String get streak_count => 'Streak Days';

  @override
  String get home_stats_title => 'Your Statistics';

  @override
  String get explore_courses => 'Explore Courses';

  @override
  String get no_courses_desc =>
      'You haven\'t started any course yet. How about discovering something new today?';

  @override
  String get no_tasks_desc =>
      'You are completely free! Want to plan a new task?';

  @override
  String get create_task => 'Create Task';

  @override
  String get pendingLabel => 'Pending';

  @override
  String get completeLabel => 'Completed';

  @override
  String get pendingFilter => 'Pending';

  @override
  String get completedFilter => 'Completed';

  @override
  String courseCardLabel(String title) {
    return 'Course: $title';
  }

  @override
  String get courseCardHint => 'Tap to view course details';

  @override
  String get progress => 'Progress';

  @override
  String get paidPrice => 'Premium';

  @override
  String get featuredLabel => 'Featured';

  @override
  String get newStatusLabel => 'New';

  @override
  String get discoverTopPicks => 'Discover our top picks';

  @override
  String get plus100Courses => '+100 Courses';

  @override
  String get exploreMore => 'Explore More';

  @override
  String get findLessons => 'What do you want to learn today?';

  @override
  String get previewLabel => 'Preview';

  @override
  String get videoLabel => 'Video';

  @override
  String get hours => 'hr';

  @override
  String get minutes => 'min';

  @override
  String get unknownInstructor => 'Unknown Instructor';

  @override
  String get studentsLabel => 'students';

  @override
  String get whatYouWillLearn => 'What you\'ll learn';

  @override
  String get learningPoint1 => 'Understand the basics and key concepts';

  @override
  String get learningPoint2 =>
      'Step-by-step practical application on real projects';

  @override
  String get learningPoint3 =>
      'Acquire skills demanded in the modern job market';

  @override
  String get coursePrerequisites => 'Prerequisites';

  @override
  String get courseLanguage => 'Language';

  @override
  String get learningObjectives => 'Learning Objectives';

  @override
  String get requirement1 => 'No prior experience required (Beginner friendly)';

  @override
  String get requirement2 => 'Good internet connection and a PC or smartphone';

  @override
  String get reviewCourse => 'Review Course';

  @override
  String get viewFullCourse => 'View Full Course';

  @override
  String get enrolledSuccessfully => 'Successfully enrolled in the course.';

  @override
  String get enrollmentFailed => 'Failed to enroll. Please try again.';

  @override
  String get fullAccessLabel => 'Full Access';

  @override
  String get permOpenSettingsManual =>
      'Please open Settings → Apps → EduZone → Permissions to enable access';

  @override
  String get permOpenSettingsError =>
      'Unable to open Settings. Please enable permissions manually.';

  @override
  String get noPreviewAvailable =>
      'No preview video available for this course.';

  @override
  String get showLess => 'Show Less';

  @override
  String get showMore => 'Show More';

  @override
  String get startNow => 'Start Now (Review)';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get paymentNotAvailable =>
      'Payment system is not available in this version. You can request a review and we will contact you.';

  @override
  String get confirmRequest => 'Confirm for Review';

  @override
  String get requestReceived => 'Request received, we will review it soon';

  @override
  String get forceUpdateTitle => 'Update Required';

  @override
  String get forceUpdateMsg =>
      'Please update the app to continue using EduZone.';

  @override
  String get forceUpdateBtn => 'Update Now';

  @override
  String get optionalUpdateTitle => 'New Update Available';

  @override
  String get optionalUpdateBtn => 'Update Now';

  @override
  String get optionalUpdateLater => 'Later';

  @override
  String get progressTitle => 'Your Progress';

  @override
  String lessonsCompleted(int completed, int total) {
    return '$completed/$total lessons';
  }

  @override
  String get courseCompleted => 'Course Completed! 🎉';

  @override
  String get overallProgress => 'Overall Progress';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String sectionProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String lastWatched(String time) {
    return 'Last watched $time';
  }

  @override
  String get notStarted => 'Not started yet';

  @override
  String get statusActive => 'Active';

  @override
  String get statusLocked => 'Locked';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusBanned => 'Banned';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get statusMaintenance => 'Maintenance';

  @override
  String get statusUnauthenticated => 'Unauthenticated';

  @override
  String get statusAppLocked => 'App Locked';

  @override
  String get statusUnrecognized => 'Unknown';

  @override
  String get downloadNotFound => 'Download not found';

  @override
  String get downloadNotReady =>
      'Download not ready — please wait for it to finish';

  @override
  String get offlineModeLabel => 'Offline mode';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsEmpty => 'No downloads yet';

  @override
  String get downloadsEmptyHint => 'Download lessons to watch offline';

  @override
  String get downloadsError => 'Error loading downloads';

  @override
  String get downloadsRetry => 'Retry';

  @override
  String get downloadsCleanupTitle => 'Clean Up Expired Downloads';

  @override
  String get downloadsCleanupMsg =>
      'Delete all expired downloads to free up storage?';

  @override
  String get downloadsCleanup => 'Clean Up';

  @override
  String get downloadsDeleteTitle => 'Delete Download';

  @override
  String get downloadsDeleteMsg =>
      'Are you sure you want to delete this download?';

  @override
  String get downloadsDeleteBtn => 'Delete';

  @override
  String get downloadsCancelBtn => 'Cancel';

  @override
  String downloadsStorageUsed(String size) {
    return 'Storage Used: $size MB';
  }

  @override
  String get downloadStatusPending => 'Pending';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusCompleted => 'Downloaded';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadExpired => 'Expired';

  @override
  String get downloadNeverExpires => 'Never expires';

  @override
  String downloadExpiresInDays(int days) {
    return 'Expires in ${days}d';
  }

  @override
  String downloadExpiresInHours(int hours) {
    return 'Expires in ${hours}h';
  }

  @override
  String get downloadExpiresSoon => 'Expires soon';

  @override
  String downloadCourseGroup(String courseId) {
    return 'Course: $courseId';
  }

  @override
  String get downloadSelectQuality => 'Select Video Quality';

  @override
  String get downloadEstimatedSizes => 'Estimated file sizes:';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Resume';

  @override
  String get downloadCancel => 'Cancel';

  @override
  String get downloadRetry => 'Retry';

  @override
  String get loadingOfflineLesson => 'Preparing offline lesson…';

  @override
  String get offlinePlaybackError => 'Could not play the offline lesson.';

  @override
  String get playButtonLabel => 'play';

  @override
  String get pauseButtonTooltip => 'pause';

  @override
  String get fullScreenButtonTooltip => 'fullscreen';

  @override
  String get exitFullScreenButtonTooltip => 'exit fullscreen';

  @override
  String get settingsTooltip => 'settings';

  @override
  String get audioSettingsTooltip => 'audio settings';

  @override
  String get speedTooltip => 'speed';

  @override
  String get volumeTooltip => 'volume';

  @override
  String get showControlsTooltip => 'show/hide controls';

  @override
  String get rewindButtonTooltip => 'rewind 10 seconds';

  @override
  String get fastForwardButtonTooltip => 'fast forward 10 seconds';

  @override
  String get toggleAspectRatioTooltip => 'toggle aspect ratio';

  @override
  String get savedCoursesTitle => 'Saved';

  @override
  String get savedCoursesEmptyMessage => 'No bookmarked courses yet';

  @override
  String get bookmarkFailed => 'Failed to update bookmark. Please try again.';

  @override
  String get bookmarkAdd => 'Add to bookmarks';

  @override
  String get bookmarkRemove => 'Remove from bookmarks';

  @override
  String get downloadLesson => 'Download lesson';

  @override
  String get shareCourse => 'Share course';

  @override
  String get videoSeekBack => 'Rewind 10 seconds';

  @override
  String get videoSeekForward => 'Forward 10 seconds';

  @override
  String get videoPlay => 'Play';

  @override
  String get videoPause => 'Pause';

  @override
  String get videoMute => 'Mute';

  @override
  String get videoUnmute => 'Unmute';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get videoEnterFullscreen => 'Enter fullscreen';

  @override
  String get videoExitFullscreen => 'Exit fullscreen';

  @override
  String get videoOrientationPortrait => 'Switch to portrait view';

  @override
  String get videoOrientationLandscape => 'Switch to landscape view';

  @override
  String get videoSwitchPlayer => 'Switch video player';

  @override
  String get navigateBack => 'Go back';

  @override
  String lessonsProgress(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'lessons',
      one: 'lesson',
    );
    return '$completed/$total $_temp0';
  }

  @override
  String downloadingTitle(String title) {
    return 'Downloading $title';
  }

  @override
  String downloadingProgress(String pct) {
    return '$pct% completed';
  }

  @override
  String get downloadingSubtitle => 'Downloading…';

  @override
  String get downloadCompleted => 'Download Completed';

  @override
  String get downloadFailed => 'Download Failed';

  @override
  String get loadingLessonData => 'Loading lesson data…';

  @override
  String get videoUrlError => 'Failed to get video URL';

  @override
  String get downloadStarting => 'Starting download…';

  @override
  String downloadStartedSuccess(String quality) {
    return 'Started downloading $quality quality successfully';
  }

  @override
  String downloadStartFailed(String error) {
    return 'Failed to start download: $error';
  }

  @override
  String videoInfoFetchFailed(String error) {
    return 'Failed to fetch video properties: $error';
  }

  @override
  String downloadActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get choosePlayer => 'Choose Player';

  @override
  String videoLoadErrorCode(int errorCode) {
    return 'Error loading video (code: $errorCode)';
  }

  @override
  String get taskInputHint => 'What needs to be done?';

  @override
  String get dismissOfflineNotice => 'Dismiss offline notice';
}
