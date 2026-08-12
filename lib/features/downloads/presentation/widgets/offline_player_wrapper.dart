/// Barrel export for the offline player widget.
///
/// This file used to contain the full implementation directly (815 lines:
/// player lifecycle/decryption logic + all UI rendering in one State
/// class). It has been split into `offline_player/` by responsibility —
/// see that folder for the actual source. This barrel keeps the original
/// import path
/// (`package:app/features/downloads/presentation/widgets/offline_player_wrapper.dart`)
/// working unchanged for existing consumers.
library;

export 'offline_player/offline_player_wrapper.dart' show OfflinePlayerWrapper;
