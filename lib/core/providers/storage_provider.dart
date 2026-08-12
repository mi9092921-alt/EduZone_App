import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/storage_service.dart';

part 'storage_provider.g.dart';

/// Core-level provider for the [StorageService] singleton.
///
/// Kept alive so the SQLite connection persists across the app lifecycle.
/// Previously defined inside the downloads feature; moved here so that
/// multiple features (downloads, bookmarks) can depend on it without
/// cross-feature imports.
@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) {
  return StorageService();
}
