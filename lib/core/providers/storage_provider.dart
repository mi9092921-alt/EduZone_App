import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/storage_service.dart';

part 'storage_provider.g.dart';

/// Core-level provider for the [StorageService] singleton.
///
/// Kept alive so the SQLite connection persists across the app lifecycle.
/// Previously defined inside the downloads feature; moved here so that
/// multiple features (downloads, bookmarks) can depend on it without
/// cross-feature imports.
///
/// Passes real secure storage explicitly (rather than relying on a
/// default inside `StorageService`) so the security-critical download
/// metadata this service writes (`security_signature`, P6.22/P6.23) is
/// actually signed in production — `StorageService`'s own constructor
/// deliberately treats a missing secure storage as "skip signing" rather
/// than throwing, exactly so tests and other lightweight instances keep
/// working without a platform channel.
@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) {
  return StorageService(secureStorage: const FlutterSecureStorage());
}
