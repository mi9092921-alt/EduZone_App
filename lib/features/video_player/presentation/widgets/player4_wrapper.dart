/// Barrel export for the Player4 video widget.
///
/// This file used to contain the full implementation directly (876 lines:
/// player lifecycle/Supabase integration + all UI rendering in one State
/// class). It has been split into `player4/` by responsibility — see that
/// folder for the actual source. This barrel keeps the original import
/// path
/// (`package:app/features/video_player/presentation/widgets/player4_wrapper.dart`)
/// working unchanged for existing consumers.
library;

export 'player4/player4_wrapper.dart' show Player4Wrapper;
