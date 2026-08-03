chore(deps): bump the minor-and-patch group with 21 updates 


Analyzing EduZone_App...                                        

  error • '_$AppThemeMode.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/app/app_providers.g.dart:50:8 • invalid_override
  error • '_$AppLocale.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/app/app_providers.g.dart:101:8 • invalid_override
   info • 'anonKey' is deprecated and shouldn't be used. Use publishableKey instead. anonKey will be removed in a future major version. Try replacing the use of the deprecated member with the replacement • lib/core/network/supabase_client.dart:26:7 • deprecated_member_use
  error • '_$Auth.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/auth/presentation/providers/auth_provider.g.dart:525:8 • invalid_override
  error • '_$UserSubscriptions.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/courses/presentation/providers/courses_provider.g.dart:1027:8 • invalid_override
  error • '_$PublicCourses.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/courses/presentation/providers/courses_provider.g.dart:1071:8 • invalid_override
  error • '_$BookmarkedCourses.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/courses/presentation/providers/courses_provider.g.dart:1322:8 • invalid_override
  error • '_$DownloadsNotifier.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/downloads/presentation/providers/downloads_provider.g.dart:636:8 • invalid_override
  error • '_$NotificationFilter.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/notifications/presentation/providers/notifications_provider.g.dart:278:8 • invalid_override
  error • '_$ProfileActions.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/profile/presentation/providers/profile_provider.g.dart:219:8 • invalid_override
  error • '_$TodoNotifier.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/todo/presentation/providers/todo_provider.g.dart:344:8 • invalid_override
  error • '_$Player4VideoInfo.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/video_player/presentation/providers/player4_provider.g.dart:135:8 • invalid_override
  error • '_$VideoProgress.runBuild' ('void Function()') isn't a valid override of 'AnyNotifier.runBuild' ('WhenComplete Function()') • lib/features/video_player/presentation/providers/video_provider.g.dart:335:8 • invalid_override
  error • '_FakeRealtimeChannel.onPostgresChanges' ('RealtimeChannel Function({required void Function(PostgresChangePayload) callback, required PostgresChangeEvent event, PostgresChangeFilter? filter, String? schema, String? table})') isn't a valid override of 'RealtimeChannel.onPostgresChanges' ('RealtimeChannel Function({required void Function(PostgresChangePayload) callback, required PostgresChangeEvent event, PostgresChangeFilter? filter, List<PostgresChangeFilter>? filters, String? schema, List<String>? select, String? table})') • test/features/auth/presentation/providers/auth_notifier_test.dart:500:19 • invalid_override

14 issues found. (ran in 23.8s)
Error: Process completed with exit code 1.



=========================================================================================================



chore(deps): bump youtube_player_flutter from 9.1.3 to 10.0.1 #25

Analyzing EduZone_App...                                        

  error • The getter 'isPlaying' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'isPlaying', correcting the name to the name of an existing getter, or defining a getter or field named 'isPlaying' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:43:46 • undefined_getter
  error • The getter 'position' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'position', correcting the name to the name of an existing getter, or defining a getter or field named 'position' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:63:53 • undefined_getter
  error • The named parameter 'seconds' is required, but there's no corresponding argument. Try adding the required argument • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:65:23 • missing_required_argument
  error • Too many positional arguments: 0 expected, but 1 found. Try removing the extra positional arguments, or specifying the name for named arguments • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:65:30 • extra_positional_arguments_could_be_named
  error • The getter 'isPlaying' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'isPlaying', correcting the name to the name of an existing getter, or defining a getter or field named 'isPlaying' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:70:33 • undefined_getter
  error • The method 'pause' isn't defined for the type 'YoutubePlayerController'. Try correcting the name to the name of an existing method, or defining a method named 'pause' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:71:25 • undefined_method
  error • The method 'play' isn't defined for the type 'YoutubePlayerController'. Try correcting the name to the name of an existing method, or defining a method named 'play' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:77:25 • undefined_method
  error • The named parameter 'onReady' isn't defined. Try correcting the name to an existing named parameter's name, or defining a named parameter with the name 'onReady' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:87:7 • undefined_named_parameter
  error • The argument type 'YoutubePlayerController' can't be assigned to the parameter type 'Listenable'.  • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:107:32 • argument_type_not_assignable
  error • The getter 'isReady' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'isReady', correcting the name to the name of an existing getter, or defining a getter or field named 'isReady' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:109:54 • undefined_getter
  error • The getter 'isPlaying' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'isPlaying', correcting the name to the name of an existing getter, or defining a getter or field named 'isPlaying' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:128:47 • undefined_getter
  error • The method 'ProgressBar' isn't defined for the type '_CustomYoutubePlayerState'. Try correcting the name to the name of an existing method, or defining a method named 'ProgressBar' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:177:17 • undefined_method
  error • The name 'ProgressBarColors' isn't a class. Try correcting the name to match an existing class • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:180:33 • creation_with_non_type
  error • The getter 'position' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'position', correcting the name to the name of an existing getter, or defining a getter or field named 'position' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:195:63 • undefined_getter
  error • The method 'PlaybackSpeedButton' isn't defined for the type '_CustomYoutubePlayerState'. Try correcting the name to the name of an existing method, or defining a method named 'PlaybackSpeedButton' • lib/features/video_player/presentation/widgets/youtube_player_widget.dart:225:32 • undefined_method
  error • The method 'convertUrlToId' isn't defined for the type 'YoutubePlayer'. Try correcting the name to the name of an existing method, or defining a method named 'convertUrlToId' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:40:35 • undefined_method
  error • The method 'dispose' isn't defined for the type 'YoutubePlayerController'. Try correcting the name to the name of an existing method, or defining a method named 'dispose' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:46:18 • undefined_method
  error • The named parameter 'initialVideoId' isn't defined. Try correcting the name to an existing named parameter's name, or defining a named parameter with the name 'initialVideoId' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:48:7 • undefined_named_parameter
  error • The named parameter 'flags' isn't defined. Try correcting the name to an existing named parameter's name, or defining a named parameter with the name 'flags' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:49:7 • undefined_named_parameter
  error • The name 'YoutubePlayerFlags' isn't a class. Try correcting the name to match an existing class • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:49:20 • creation_with_non_type
  error • The method 'addListener' isn't defined for the type 'YoutubePlayerController'. Try correcting the name to the name of an existing method, or defining a method named 'addListener' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:52:8 • undefined_method
  error • The getter 'isReady' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'isReady', correcting the name to the name of an existing getter, or defining a getter or field named 'isReady' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:58:64 • undefined_getter
  error • The getter 'position' isn't defined for the type 'YoutubePlayerValue'. Try importing the library that defines 'position', correcting the name to the name of an existing getter, or defining a getter or field named 'position' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:66:41 • undefined_getter
  error • The method 'dispose' isn't defined for the type 'YoutubePlayerController'. Try correcting the name to the name of an existing method, or defining a method named 'dispose' • lib/features/video_player/presentation/widgets/youtube_player_wrapper.dart:104:18 • undefined_method

24 issues found. (ran in 27.1s)
Error: Process completed with exit code 1.