/// Barrel export for the modern (WebView-based) YouTube player widget.
///
/// This file used to contain the full implementation directly (652 lines,
/// dominated by a ~260-line inline HTML/JS string builder). It has been
/// split into `modern_player/` by responsibility — see that folder for the
/// actual source. This barrel keeps the original import path
/// (`package:app/features/video_player/presentation/widgets/modern_player_wrapper.dart`)
/// working unchanged for existing consumers.
library;

export 'modern_player/modern_player_wrapper.dart' show ModernPlayerWrapper;
