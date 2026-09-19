import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../security/secure_storage_config.dart';
import 'certificate_pinning.dart';

class SupabaseService {
  static Future<void> initialize() async {
    if (AppConstants.supabaseUrl.isEmpty ||
        AppConstants.supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase credentials are empty!\n'
        'Build with: flutter build apk --release --dart-define-from-file=.env\n'
        'Or run with: flutter run --dart-define-from-file=.env',
      );
    }

    final certs = await loadPinnedCertificatesAsset();

    // Fail fast instead of silently degrading: if BOTH pinned-cert assets
    // are missing/mis-bundled in a release build, falling through to the
    // default HTTP client would trust the device's full OS CA store —
    // exactly the MITM surface pinning exists to close (SEC-001). Mirror
    // the freeRASP misconfiguration fail-fast in freerasp_config.dart.
    // Debug/profile builds intentionally bypass pinning (see
    // loadPinnedCertificatesAsset) so local development keeps working.
    if (kReleaseMode && certs.isEmpty) {
      throw StateError(
        'Certificate pinning assets failed to load in a release build '
        '(assets/certs/supabase.pem + assets/certs/backup_ca.pem). '
        'Refusing to start without TLS pinning — verify the assets are '
        'declared under flutter/assets in pubspec.yaml and bundled.',
      );
    }

    final customClient = certs.isNotEmpty
        ? IOClient(createPinnedHttpClient(certs))
        : null;

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
      httpClient: customClient,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

/// Secure storage implementation for Supabase session.
/// Uses Hardware-backed Keystore/Keychain via flutter_secure_storage.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    return hardenedSecureStorage.read(key: 'supabase_access_token');
  }

  @override
  Future<bool> hasAccessToken() async {
    return hardenedSecureStorage.containsKey(key: 'supabase_access_token');
  }

  @override
  Future<void> persistSession(String session) async {
    await hardenedSecureStorage.write(
      key: 'supabase_access_token',
      value: session,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await hardenedSecureStorage.delete(key: 'supabase_access_token');
  }
}
