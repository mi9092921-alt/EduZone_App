import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
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
    final customClient = certs.isNotEmpty
        ? IOClient(createPinnedHttpClient(certs))
        : null;

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
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
    return const FlutterSecureStorage().read(key: 'supabase_access_token');
  }

  @override
  Future<bool> hasAccessToken() async {
    return const FlutterSecureStorage().containsKey(key: 'supabase_access_token');
  }

  @override
  Future<void> persistSession(String session) async {
    await const FlutterSecureStorage().write(
      key: 'supabase_access_token',
      value: session,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await const FlutterSecureStorage().delete(key: 'supabase_access_token');
  }
}
