import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EduZone'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access your learning journey'**
  String get loginSubtitle;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @discoverTab.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTab;

  /// No description provided for @coursesTab.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get coursesTab;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @sectionsLabel.
  ///
  /// In en, this message translates to:
  /// **'sections'**
  String get sectionsLabel;

  /// No description provided for @todoTab.
  ///
  /// In en, this message translates to:
  /// **'To-Do'**
  String get todoTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorNetwork;

  /// No description provided for @errorAuth.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get errorAuth;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email before signing in.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorLocked.
  ///
  /// In en, this message translates to:
  /// **'Account is locked due to multiple failed attempts.'**
  String get errorLocked;

  /// No description provided for @errorBanned.
  ///
  /// In en, this message translates to:
  /// **'Your account has been banned.'**
  String get errorBanned;

  /// No description provided for @errorSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your account is temporarily suspended.'**
  String get errorSuspended;

  /// No description provided for @errorMaintenance.
  ///
  /// In en, this message translates to:
  /// **'System is under maintenance. Please check back later.'**
  String get errorMaintenance;

  /// No description provided for @errorEmulatorBlocked.
  ///
  /// In en, this message translates to:
  /// **'Cannot sign in from an emulator.'**
  String get errorEmulatorBlocked;

  /// No description provided for @errorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, wait {minutes} minutes.'**
  String errorRateLimit(int minutes);

  /// No description provided for @errorMaxDevices.
  ///
  /// In en, this message translates to:
  /// **'Device limit reached (1 device).'**
  String get errorMaxDevices;

  /// No description provided for @errorDeviceBound.
  ///
  /// In en, this message translates to:
  /// **'Device registered to another account.'**
  String get errorDeviceBound;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @lockedScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Locked'**
  String get lockedScreenTitle;

  /// No description provided for @lockedScreenMsg.
  ///
  /// In en, this message translates to:
  /// **'Your account has been locked for security reasons. Please contact support to unlock it.'**
  String get lockedScreenMsg;

  /// No description provided for @lockedScreenContactBtn.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get lockedScreenContactBtn;

  /// No description provided for @bannedScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Banned'**
  String get bannedScreenTitle;

  /// No description provided for @bannedScreenMsg.
  ///
  /// In en, this message translates to:
  /// **'This account has been permanently banned from EduZone due to violations of our Terms of Service.'**
  String get bannedScreenMsg;

  /// No description provided for @bannedScreenAppeal.
  ///
  /// In en, this message translates to:
  /// **'If you believe this is a mistake, you can appeal this decision by emailing appeals@eduzone.com'**
  String get bannedScreenAppeal;

  /// No description provided for @suspendedScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get suspendedScreenTitle;

  /// No description provided for @suspendedScreenMsg.
  ///
  /// In en, this message translates to:
  /// **'Your access has been temporarily suspended. Please check your email for more details or contact your administrator.'**
  String get suspendedScreenMsg;

  /// No description provided for @suspendedScreenCheckStatusBtn.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get suspendedScreenCheckStatusBtn;

  /// No description provided for @maintenanceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Under Maintenance'**
  String get maintenanceScreenTitle;

  /// No description provided for @maintenanceScreenMsg.
  ///
  /// In en, this message translates to:
  /// **'We are currently performing scheduled maintenance to improve our services. We will be back shortly!'**
  String get maintenanceScreenMsg;

  /// No description provided for @maintenanceScreenEstTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated time: 15 minutes'**
  String get maintenanceScreenEstTime;

  /// No description provided for @maintenanceScreenEndTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated end time: {time}'**
  String maintenanceScreenEndTime(String time);

  /// No description provided for @statusReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String statusReason(String reason);

  /// No description provided for @statusUntil.
  ///
  /// In en, this message translates to:
  /// **'Until: {time}'**
  String statusUntil(String time);

  /// No description provided for @welcome_user.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {firstName} 👋'**
  String welcome_user(String firstName);

  /// No description provided for @continue_learning.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continue_learning;

  /// No description provided for @recent_courses.
  ///
  /// In en, this message translates to:
  /// **'Recent Courses'**
  String get recent_courses;

  /// No description provided for @today_todos.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Tasks'**
  String get today_todos;

  /// No description provided for @no_recent_courses.
  ///
  /// In en, this message translates to:
  /// **'No recent courses.'**
  String get no_recent_courses;

  /// No description provided for @no_recent_todos.
  ///
  /// In en, this message translates to:
  /// **'No tasks for today.'**
  String get no_recent_todos;

  /// No description provided for @no_courses_available.
  ///
  /// In en, this message translates to:
  /// **'No courses available.'**
  String get no_courses_available;

  /// No description provided for @see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get see_all;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @lessonNotFound.
  ///
  /// In en, this message translates to:
  /// **'Lesson not found'**
  String get lessonNotFound;

  /// No description provided for @enrollmentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enrollment Required'**
  String get enrollmentRequired;

  /// No description provided for @enrollToAccessLesson.
  ///
  /// In en, this message translates to:
  /// **'Please enroll in this course to access this lesson and its full content.'**
  String get enrollToAccessLesson;

  /// No description provided for @viewEnrollmentOptions.
  ///
  /// In en, this message translates to:
  /// **'View Enrollment Options'**
  String get viewEnrollmentOptions;

  /// No description provided for @chooseVideoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Choose video player'**
  String get chooseVideoPlayer;

  /// No description provided for @youtubePlayer.
  ///
  /// In en, this message translates to:
  /// **'YouTube Player'**
  String get youtubePlayer;

  /// No description provided for @youtubePlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard Flutter player'**
  String get youtubePlayerSubtitle;

  /// No description provided for @modernPlayer.
  ///
  /// In en, this message translates to:
  /// **'Modern Player'**
  String get modernPlayer;

  /// No description provided for @modernPlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WebView experience with UI cleanup'**
  String get modernPlayerSubtitle;

  /// No description provided for @directPlayer.
  ///
  /// In en, this message translates to:
  /// **'Direct Player'**
  String get directPlayer;

  /// No description provided for @directPlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High-quality playback without WebView'**
  String get directPlayerSubtitle;

  /// No description provided for @normalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalSpeed;

  /// No description provided for @retryLoading.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLoading;

  /// No description provided for @checkInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again'**
  String get checkInternetConnection;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected server error'**
  String get serverError;

  /// No description provided for @videoParseError.
  ///
  /// In en, this message translates to:
  /// **'Video data error. Please try again or contact support.'**
  String get videoParseError;

  /// No description provided for @autoQuality.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoQuality;

  /// No description provided for @invalidVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid Video URL'**
  String get invalidVideoUrl;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get markAsDone;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorLoading(String message);

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get tasksTitle;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String allTasks(int count);

  /// No description provided for @pendingTasks.
  ///
  /// In en, this message translates to:
  /// **'Pending ({count})'**
  String pendingTasks(int count);

  /// No description provided for @completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String completedTasks(int count);

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks found'**
  String get noTasks;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add New Task'**
  String get addTask;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get editTask;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete Task'**
  String get deleteTask;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task? This action cannot be undone.'**
  String get confirmDeleteMsg;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitleHint;

  /// No description provided for @taskDescHint.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get taskDescHint;

  /// No description provided for @taskPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get taskPriority;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDateLabel;

  /// No description provided for @addBtn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addBtn;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @taskAdded.
  ///
  /// In en, this message translates to:
  /// **'Task added successfully'**
  String get taskAdded;

  /// No description provided for @taskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Task updated successfully'**
  String get taskUpdated;

  /// No description provided for @taskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Task deleted successfully'**
  String get taskDeleted;

  /// No description provided for @overdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue: {time}'**
  String overdueLabel(String time);

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due: {time}'**
  String dueLabel(String time);

  /// No description provided for @minCount.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minCount(int count);

  /// No description provided for @lessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No lessons} =1{1 lesson} other{{count} lessons}}'**
  String lessonsCount(int count);

  /// No description provided for @noContentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No content available.'**
  String get noContentAvailable;

  /// No description provided for @searchCourses.
  ///
  /// In en, this message translates to:
  /// **'Search Courses'**
  String get searchCourses;

  /// No description provided for @failedToLoadCourses.
  ///
  /// In en, this message translates to:
  /// **'Failed to load courses. Pull to refresh.'**
  String get failedToLoadCourses;

  /// No description provided for @generalCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalCategory;

  /// No description provided for @errorLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Error loading tasks'**
  String get errorLoadingTasks;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get errorPasswordTooShort;

  /// No description provided for @levelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get levelIntermediate;

  /// No description provided for @levelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get levelAdvanced;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @notEnrolledMsg.
  ///
  /// In en, this message translates to:
  /// **'You are not enrolled in this course.'**
  String get notEnrolledMsg;

  /// No description provided for @courseProgress.
  ///
  /// In en, this message translates to:
  /// **'Course Progress'**
  String get courseProgress;

  /// No description provided for @enrollmentSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your enrollment is suspended.'**
  String get enrollmentSuspended;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out...'**
  String get loggingOut;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @deviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceInfo;

  /// No description provided for @verifiedDevice.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedDevice;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changeAvatar;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdated;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated successfully'**
  String get avatarUpdated;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out? You will need to sign in again.'**
  String get logoutConfirmMsg;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @noInternetBanner.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetBanner;

  /// No description provided for @suspendedCountdown.
  ///
  /// In en, this message translates to:
  /// **'Time remaining: {days}d {hours}h {minutes}m'**
  String suspendedCountdown(int days, int hours, int minutes);

  /// No description provided for @maintenanceCountdown.
  ///
  /// In en, this message translates to:
  /// **'Estimated time remaining: {hours}h {minutes}m'**
  String maintenanceCountdown(int hours, int minutes);

  /// No description provided for @supportAndInfo.
  ///
  /// In en, this message translates to:
  /// **'Support & Info'**
  String get supportAndInfo;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @followUs.
  ///
  /// In en, this message translates to:
  /// **'Follow Us'**
  String get followUs;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsContent.
  ///
  /// In en, this message translates to:
  /// **'By using EduZone, you agree to comply with all the terms and conditions outlined in this agreement. EduZone is designed to provide high-quality digital educational services powered by modern technologies. All content is provided \"as is\" without any express or implied warranties regarding accuracy, completeness, or suitability for a particular purpose. Users are required to use the platform in a lawful and ethical manner and must not engage in any misuse, including but not limited to unauthorized access, attempts to breach system security, or the distribution of harmful or misleading content. EduZone reserves the right to modify or update these terms at any time without prior notice, and continued use of the platform constitutes acceptance of those changes. The platform administration also reserves the right to suspend or terminate user accounts in cases of violations or misuse, in order to protect the integrity of the system and other users.'**
  String get termsContent;

  /// No description provided for @privacyContent.
  ///
  /// In en, this message translates to:
  /// **'At EduZone, we place the highest priority on protecting user privacy and personal data. We collect only the necessary information required to enhance the quality of our educational services, such as registration details, usage activity, and interactions within the platform. This data is used to improve user experience, personalize educational content, and optimize overall system performance. We are committed to not selling or sharing user data with third parties without explicit consent, except where required by law or to protect our legal rights. All data is stored using advanced security standards, including encryption and strict access controls, to safeguard against unauthorized access or data breaches. By using the platform, you agree to this privacy policy, while retaining the right to request access, modification, or deletion of your data in accordance with applicable policies.'**
  String get privacyContent;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Conditions and Privacy Policy'**
  String get agreeToTerms;

  /// No description provided for @agreeToTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get agreeToTermsPrefix;

  /// No description provided for @agreeToTermsMiddle.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get agreeToTermsMiddle;

  /// No description provided for @agreeToTermsSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get agreeToTermsSuffix;

  /// No description provided for @agreeToTermsError.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms and conditions to continue'**
  String get agreeToTermsError;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get errorInvalidEmail;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated: {date}'**
  String lastUpdated(String date);

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} EduZone Platform'**
  String copyright(String year);

  /// No description provided for @errorLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Link unavailable'**
  String get errorLinkUnavailable;

  /// No description provided for @modernLearningPlatform.
  ///
  /// In en, this message translates to:
  /// **'Modern learning platform for students and teachers'**
  String get modernLearningPlatform;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @copyrightFull.
  ///
  /// In en, this message translates to:
  /// **'EduZone Platform © {year}. All rights reserved.'**
  String copyrightFull(String year);

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String versionLabel(String version);

  /// No description provided for @emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get emailCopied;

  /// No description provided for @defaultUserName.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get defaultUserName;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to boost your skills today?'**
  String get welcomeSubtitle;

  /// No description provided for @permissionsHeader.
  ///
  /// In en, this message translates to:
  /// **'App Permissions'**
  String get permissionsHeader;

  /// No description provided for @locationPermission.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationPermission;

  /// No description provided for @locationPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Used to personalize nearby learning experiences and location-aware features.'**
  String get locationPermissionDescription;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraPermission;

  /// No description provided for @cameraPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Used when you capture a profile photo or submit visual course work.'**
  String get cameraPermissionDescription;

  /// No description provided for @mediaPermission.
  ///
  /// In en, this message translates to:
  /// **'Photos & Files'**
  String get mediaPermission;

  /// No description provided for @mediaPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Used when you upload study materials, attachments, and profile images.'**
  String get mediaPermissionDescription;

  /// No description provided for @storagePermission.
  ///
  /// In en, this message translates to:
  /// **'Storage & Camera'**
  String get storagePermission;

  /// No description provided for @notificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationPermission;

  /// No description provided for @notificationPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Used to alert you about deadlines, course activity, and important updates.'**
  String get notificationPermissionDescription;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionDenied;

  /// No description provided for @permissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Disabled (Settings)'**
  String get permissionPermanentlyDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @permDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permDeniedTitle;

  /// No description provided for @permDeniedMsg.
  ///
  /// In en, this message translates to:
  /// **'This feature requires {permission} access. Since it was permanently denied, please enable it manually in the system settings.'**
  String permDeniedMsg(String permission);

  /// No description provided for @permActionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get permActionOpenSettings;

  /// No description provided for @lessonsLabel.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessonsLabel;

  /// No description provided for @courseDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'About this Course'**
  String get courseDescriptionLabel;

  /// No description provided for @courseCurriculumLabel.
  ///
  /// In en, this message translates to:
  /// **'Course Content'**
  String get courseCurriculumLabel;

  /// No description provided for @instructorLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get instructorLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @freeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeLabel;

  /// No description provided for @enrollNow.
  ///
  /// In en, this message translates to:
  /// **'Enroll Now'**
  String get enrollNow;

  /// No description provided for @enrollmentComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Enrollment functionality is coming soon!'**
  String get enrollmentComingSoon;

  /// No description provided for @resumeLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get resumeLearning;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @unreadFilter.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unreadFilter;

  /// No description provided for @noUnreadNotifications.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get noUnreadNotifications;

  /// No description provided for @notificationsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'We will notify you when something important happens.'**
  String get notificationsEmptyDesc;

  /// No description provided for @daily_progress.
  ///
  /// In en, this message translates to:
  /// **'Daily Progress'**
  String get daily_progress;

  /// No description provided for @learning_time.
  ///
  /// In en, this message translates to:
  /// **'Learning Time'**
  String get learning_time;

  /// No description provided for @streak_count.
  ///
  /// In en, this message translates to:
  /// **'Streak Days'**
  String get streak_count;

  /// No description provided for @home_stats_title.
  ///
  /// In en, this message translates to:
  /// **'Your Statistics'**
  String get home_stats_title;

  /// No description provided for @explore_courses.
  ///
  /// In en, this message translates to:
  /// **'Explore Courses'**
  String get explore_courses;

  /// No description provided for @no_courses_desc.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t started any course yet. How about discovering something new today?'**
  String get no_courses_desc;

  /// No description provided for @no_tasks_desc.
  ///
  /// In en, this message translates to:
  /// **'You are completely free! Want to plan a new task?'**
  String get no_tasks_desc;

  /// No description provided for @create_task.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get create_task;

  /// No description provided for @pendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingLabel;

  /// No description provided for @completeLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completeLabel;

  /// No description provided for @pendingFilter.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingFilter;

  /// No description provided for @completedFilter.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedFilter;

  /// No description provided for @courseCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Course: {title}'**
  String courseCardLabel(String title);

  /// No description provided for @courseCardHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to view course details'**
  String get courseCardHint;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @paidPrice.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get paidPrice;

  /// No description provided for @featuredLabel.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredLabel;

  /// No description provided for @newStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newStatusLabel;

  /// No description provided for @discoverTopPicks.
  ///
  /// In en, this message translates to:
  /// **'Discover our top picks'**
  String get discoverTopPicks;

  /// No description provided for @plus100Courses.
  ///
  /// In en, this message translates to:
  /// **'+100 Courses'**
  String get plus100Courses;

  /// No description provided for @exploreMore.
  ///
  /// In en, this message translates to:
  /// **'Explore More'**
  String get exploreMore;

  /// No description provided for @findLessons.
  ///
  /// In en, this message translates to:
  /// **'What do you want to learn today?'**
  String get findLessons;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoLabel;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @unknownInstructor.
  ///
  /// In en, this message translates to:
  /// **'Unknown Instructor'**
  String get unknownInstructor;

  /// No description provided for @studentsLabel.
  ///
  /// In en, this message translates to:
  /// **'students'**
  String get studentsLabel;

  /// No description provided for @whatYouWillLearn.
  ///
  /// In en, this message translates to:
  /// **'What you\'ll learn'**
  String get whatYouWillLearn;

  /// No description provided for @learningPoint1.
  ///
  /// In en, this message translates to:
  /// **'Understand the basics and key concepts'**
  String get learningPoint1;

  /// No description provided for @learningPoint2.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step practical application on real projects'**
  String get learningPoint2;

  /// No description provided for @learningPoint3.
  ///
  /// In en, this message translates to:
  /// **'Acquire skills demanded in the modern job market'**
  String get learningPoint3;

  /// No description provided for @coursePrerequisites.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites'**
  String get coursePrerequisites;

  /// No description provided for @courseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get courseLanguage;

  /// No description provided for @learningObjectives.
  ///
  /// In en, this message translates to:
  /// **'Learning Objectives'**
  String get learningObjectives;

  /// No description provided for @requirement1.
  ///
  /// In en, this message translates to:
  /// **'No prior experience required (Beginner friendly)'**
  String get requirement1;

  /// No description provided for @requirement2.
  ///
  /// In en, this message translates to:
  /// **'Good internet connection and a PC or smartphone'**
  String get requirement2;

  /// No description provided for @reviewCourse.
  ///
  /// In en, this message translates to:
  /// **'Review Course'**
  String get reviewCourse;

  /// No description provided for @viewFullCourse.
  ///
  /// In en, this message translates to:
  /// **'View Full Course'**
  String get viewFullCourse;

  /// No description provided for @enrolledSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Successfully enrolled in the course.'**
  String get enrolledSuccessfully;

  /// No description provided for @enrollmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enroll. Please try again.'**
  String get enrollmentFailed;

  /// No description provided for @fullAccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Access'**
  String get fullAccessLabel;

  /// No description provided for @permOpenSettingsManual.
  ///
  /// In en, this message translates to:
  /// **'Please open Settings → Apps → EduZone → Permissions to enable access'**
  String get permOpenSettingsManual;

  /// No description provided for @permOpenSettingsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Settings. Please enable permissions manually.'**
  String get permOpenSettingsError;

  /// No description provided for @noPreviewAvailable.
  ///
  /// In en, this message translates to:
  /// **'No preview video available for this course.'**
  String get noPreviewAvailable;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Start Now (Review)'**
  String get startNow;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @paymentNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Payment system is not available in this version. You can request a review and we will contact you.'**
  String get paymentNotAvailable;

  /// No description provided for @confirmRequest.
  ///
  /// In en, this message translates to:
  /// **'Confirm for Review'**
  String get confirmRequest;

  /// No description provided for @requestReceived.
  ///
  /// In en, this message translates to:
  /// **'Request received, we will review it soon'**
  String get requestReceived;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateMsg.
  ///
  /// In en, this message translates to:
  /// **'Please update the app to continue using EduZone.'**
  String get forceUpdateMsg;

  /// No description provided for @forceUpdateBtn.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get forceUpdateBtn;

  /// No description provided for @optionalUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'New Update Available'**
  String get optionalUpdateTitle;

  /// No description provided for @optionalUpdateBtn.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get optionalUpdateBtn;

  /// No description provided for @optionalUpdateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get optionalUpdateLater;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Progress'**
  String get progressTitle;

  /// No description provided for @lessonsCompleted.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} lessons'**
  String lessonsCompleted(int completed, int total);

  /// No description provided for @courseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Course Completed! 🎉'**
  String get courseCompleted;

  /// No description provided for @overallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get overallProgress;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @sectionProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total}'**
  String sectionProgress(int completed, int total);

  /// No description provided for @lastWatched.
  ///
  /// In en, this message translates to:
  /// **'Last watched {time}'**
  String lastWatched(String time);

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started yet'**
  String get notStarted;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get statusLocked;

  /// No description provided for @statusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get statusSuspended;

  /// No description provided for @statusBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get statusBanned;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @statusMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get statusMaintenance;

  /// No description provided for @statusUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Unauthenticated'**
  String get statusUnauthenticated;

  /// No description provided for @statusAppLocked.
  ///
  /// In en, this message translates to:
  /// **'App Locked'**
  String get statusAppLocked;

  /// No description provided for @statusUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statusUnrecognized;

  /// No description provided for @downloadNotFound.
  ///
  /// In en, this message translates to:
  /// **'Download not found'**
  String get downloadNotFound;

  /// No description provided for @downloadNotReady.
  ///
  /// In en, this message translates to:
  /// **'Download not ready — please wait for it to finish'**
  String get downloadNotReady;

  /// No description provided for @offlineModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineModeLabel;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorGeneric;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get downloadsEmpty;

  /// No description provided for @downloadsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Download lessons to watch offline'**
  String get downloadsEmptyHint;

  /// No description provided for @downloadsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading downloads'**
  String get downloadsError;

  /// No description provided for @downloadsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadsRetry;

  /// No description provided for @downloadsCleanupTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean Up Expired Downloads'**
  String get downloadsCleanupTitle;

  /// No description provided for @downloadsCleanupMsg.
  ///
  /// In en, this message translates to:
  /// **'Delete all expired downloads to free up storage?'**
  String get downloadsCleanupMsg;

  /// No description provided for @downloadsCleanup.
  ///
  /// In en, this message translates to:
  /// **'Clean Up'**
  String get downloadsCleanup;

  /// No description provided for @downloadsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Download'**
  String get downloadsDeleteTitle;

  /// No description provided for @downloadsDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this download?'**
  String get downloadsDeleteMsg;

  /// No description provided for @downloadsDeleteBtn.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloadsDeleteBtn;

  /// No description provided for @downloadsCancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadsCancelBtn;

  /// No description provided for @downloadsStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'Storage Used: {size} MB'**
  String downloadsStorageUsed(String size);

  /// No description provided for @downloadStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get downloadStatusPending;

  /// No description provided for @downloadStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadStatusDownloading;

  /// No description provided for @downloadStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadStatusPaused;

  /// No description provided for @downloadStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadStatusCompleted;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStatusFailed;

  /// No description provided for @downloadExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get downloadExpired;

  /// No description provided for @downloadNeverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get downloadNeverExpires;

  /// No description provided for @downloadExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days}d'**
  String downloadExpiresInDays(int days);

  /// No description provided for @downloadExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours}h'**
  String downloadExpiresInHours(int hours);

  /// No description provided for @downloadExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'Expires soon'**
  String get downloadExpiresSoon;

  /// No description provided for @downloadCourseGroup.
  ///
  /// In en, this message translates to:
  /// **'Course: {courseId}'**
  String downloadCourseGroup(String courseId);

  /// No description provided for @downloadSelectQuality.
  ///
  /// In en, this message translates to:
  /// **'Select Video Quality'**
  String get downloadSelectQuality;

  /// No description provided for @downloadEstimatedSizes.
  ///
  /// In en, this message translates to:
  /// **'Estimated file sizes:'**
  String get downloadEstimatedSizes;

  /// No description provided for @downloadPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPause;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResume;

  /// No description provided for @downloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadCancel;

  /// No description provided for @downloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadRetry;

  /// No description provided for @loadingOfflineLesson.
  ///
  /// In en, this message translates to:
  /// **'Preparing offline lesson…'**
  String get loadingOfflineLesson;

  /// No description provided for @offlinePlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Could not play the offline lesson.'**
  String get offlinePlaybackError;

  /// No description provided for @playButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'play'**
  String get playButtonLabel;

  /// No description provided for @pauseButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'pause'**
  String get pauseButtonTooltip;

  /// No description provided for @fullScreenButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'fullscreen'**
  String get fullScreenButtonTooltip;

  /// No description provided for @exitFullScreenButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'exit fullscreen'**
  String get exitFullScreenButtonTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'settings'**
  String get settingsTooltip;

  /// No description provided for @audioSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'audio settings'**
  String get audioSettingsTooltip;

  /// No description provided for @speedTooltip.
  ///
  /// In en, this message translates to:
  /// **'speed'**
  String get speedTooltip;

  /// No description provided for @volumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'volume'**
  String get volumeTooltip;

  /// No description provided for @showControlsTooltip.
  ///
  /// In en, this message translates to:
  /// **'show/hide controls'**
  String get showControlsTooltip;

  /// No description provided for @rewindButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'rewind 10 seconds'**
  String get rewindButtonTooltip;

  /// No description provided for @fastForwardButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'fast forward 10 seconds'**
  String get fastForwardButtonTooltip;

  /// No description provided for @toggleAspectRatioTooltip.
  ///
  /// In en, this message translates to:
  /// **'toggle aspect ratio'**
  String get toggleAspectRatioTooltip;

  /// No description provided for @savedCoursesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedCoursesTitle;

  /// No description provided for @savedCoursesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No bookmarked courses yet'**
  String get savedCoursesEmptyMessage;

  /// No description provided for @bookmarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update bookmark. Please try again.'**
  String get bookmarkFailed;

  /// No description provided for @bookmarkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to bookmarks'**
  String get bookmarkAdd;

  /// No description provided for @bookmarkRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from bookmarks'**
  String get bookmarkRemove;

  /// No description provided for @downloadLesson.
  ///
  /// In en, this message translates to:
  /// **'Download lesson'**
  String get downloadLesson;

  /// No description provided for @shareCourse.
  ///
  /// In en, this message translates to:
  /// **'Share course'**
  String get shareCourse;

  /// No description provided for @videoSeekBack.
  ///
  /// In en, this message translates to:
  /// **'Rewind 10 seconds'**
  String get videoSeekBack;

  /// No description provided for @videoSeekForward.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get videoSeekForward;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlay;

  /// No description provided for @videoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoPause;

  /// No description provided for @videoMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get videoMute;

  /// No description provided for @videoUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get videoUnmute;

  /// No description provided for @passwordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// No description provided for @videoEnterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Enter fullscreen'**
  String get videoEnterFullscreen;

  /// No description provided for @videoExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get videoExitFullscreen;

  /// No description provided for @videoOrientationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Switch to portrait view'**
  String get videoOrientationPortrait;

  /// No description provided for @videoOrientationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Switch to landscape view'**
  String get videoOrientationLandscape;

  /// No description provided for @videoSwitchPlayer.
  ///
  /// In en, this message translates to:
  /// **'Switch video player'**
  String get videoSwitchPlayer;

  /// No description provided for @navigateBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get navigateBack;

  /// No description provided for @lessonsProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} {total, plural, =1{lesson} other{lessons}}'**
  String lessonsProgress(int completed, int total);

  /// No description provided for @downloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading {title}'**
  String downloadingTitle(String title);

  /// No description provided for @downloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'{pct}% completed'**
  String downloadingProgress(String pct);

  /// No description provided for @downloadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloadingSubtitle;

  /// No description provided for @downloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Download Completed'**
  String get downloadCompleted;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get downloadFailed;

  /// No description provided for @loadingLessonData.
  ///
  /// In en, this message translates to:
  /// **'Loading lesson data…'**
  String get loadingLessonData;

  /// No description provided for @videoUrlError.
  ///
  /// In en, this message translates to:
  /// **'Failed to get video URL'**
  String get videoUrlError;

  /// No description provided for @downloadStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting download…'**
  String get downloadStarting;

  /// No description provided for @downloadStartedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Started downloading {quality} quality successfully'**
  String downloadStartedSuccess(String quality);

  /// No description provided for @downloadStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start download: {error}'**
  String downloadStartFailed(String error);

  /// No description provided for @videoInfoFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch video properties: {error}'**
  String videoInfoFetchFailed(String error);

  /// No description provided for @downloadActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String downloadActionFailed(String error);

  /// No description provided for @choosePlayer.
  ///
  /// In en, this message translates to:
  /// **'Choose Player'**
  String get choosePlayer;

  /// No description provided for @videoLoadErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Error loading video (code: {errorCode})'**
  String videoLoadErrorCode(int errorCode);

  /// No description provided for @taskInputHint.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done?'**
  String get taskInputHint;

  /// No description provided for @dismissOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss offline notice'**
  String get dismissOfflineNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
