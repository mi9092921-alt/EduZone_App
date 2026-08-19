import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Default asset paths for pinned certificates.
const List<String> defaultPinnedCertAssets = [
  'assets/certs/supabase.pem',
  'assets/certs/backup_ca.pem',
];

/// Checks whether a given [url] host belongs to Supabase infrastructure
/// (e.g., `*.supabase.co`, `*.supabase.in`, `*.supabase.net`, or matching `configuredSupabaseUrl`).
bool isSupabaseHost(String url, {String? configuredSupabaseUrl}) {
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;

    if (configuredSupabaseUrl != null && configuredSupabaseUrl.isNotEmpty) {
      try {
        final configUri = Uri.parse(configuredSupabaseUrl);
        if (configUri.host.isNotEmpty && host == configUri.host.toLowerCase()) {
          return true;
        }
      } catch (_) {
        // Malformed configuredSupabaseUrl: falls through to the
        // hostname-suffix checks below rather than treating it as a
        // match. This function only decides *which* hostnames are
        // treated as Supabase for pinning purposes -- it is not itself
        // the pinning/validation boundary -- so failing safe here means
        // "don't grant this optional exact-match", not "skip pinning".
      }
    }

    return host.endsWith('.supabase.co') ||
        host.endsWith('.supabase.in') ||
        host.endsWith('.supabase.net') ||
        host.endsWith('.supabase.com') ||
        host == 'supabase.co' ||
        host == 'supabase.com';
  } catch (_) {
    return false;
  }
}

/// Asynchronously loads certificate bytes from asset paths.
/// Returns a list of byte arrays representing PEM certificates that were found
/// and loaded successfully.
///
/// By default, in non-release modes (`!kReleaseMode`), pinning is bypassed (returns `[]`)
/// to prevent TLS handshake failures caused by local environment or placeholder certificates.
/// Pass [onlyInRelease: false] to force loading certs in non-release modes if needed.
///
/// Emits a [debugPrint] warning for any asset that fails to load so that
/// broken asset bundles are caught during development rather than silently
/// degrading pinning coverage in production.
Future<List<List<int>>> loadPinnedCertificatesAsset({
  List<String> assetPaths = defaultPinnedCertAssets,
  bool onlyInRelease = true,
}) async {
  if (onlyInRelease && !kReleaseMode) {
    return [];
  }
  final List<List<int>> certs = [];
  for (final path in assetPaths) {
    try {
      final byteData = await rootBundle.load(path);
      certs.add(byteData.buffer.asUint8List());
    } catch (e) {
      // In production, an asset that is missing means one fewer pinned cert.
      // Warn loudly in debug mode so developers catch this before shipping.
      if (kDebugMode) {
        debugPrint(
          '⚠️ [CertificatePinning] Failed to load pinned cert asset "$path": $e. '
          'Verify the path is declared under flutter/assets in pubspec.yaml.',
        );
      }
    }
  }
  return certs;
}

/// Creates a [SecurityContext] configured with [pinnedCertificatesPem] and `withTrustedRoots: false`.
///
/// Setting `withTrustedRoots: false` forces [SecurityContext] to ignore all device/OS
/// system root CAs and ONLY trust the certificates explicitly passed in [pinnedCertificatesPem].
SecurityContext createPinnedSecurityContext(List<List<int>> pinnedCertificatesPem) {
  if (pinnedCertificatesPem.isEmpty) {
    throw ArgumentError(
      'createPinnedSecurityContext called with no pinned certificates. '
      'Provide at least one PEM certificate — see the doc comment on this '
      'function for how to obtain it. Do not call this with an empty list '
      '"just to enable pinning later"; that would silently pin to nothing.',
    );
  }

  // withTrustedRoots: false is intentional and security-critical — it disables
  // trust in the device's entire OS CA store. Never remove this argument.
  // ignore: avoid_redundant_argument_values
  final context = SecurityContext(withTrustedRoots: false);


  for (final pem in pinnedCertificatesPem) {
    context.setTrustedCertificatesBytes(pem);
  }
  return context;
}

/// Creates a `dart:io` [HttpClient] configured with pinned TLS certificates.
HttpClient createPinnedHttpClient(List<List<int>> pinnedCertificatesPem) {
  final context = createPinnedSecurityContext(pinnedCertificatesPem);
  return HttpClient(context: context);
}

/// Pins [dio]'s TLS connections to a known-good server certificate instead of
/// trusting the device's/OS's full certificate store.
///
/// Without this, a compromised device with a rogue CA installed (or a
/// malicious proxy on public Wi-Fi) can present a certificate that passes
/// normal validation, silently intercepting traffic (signed video URLs,
/// auth tokens, ...) — see SEC-001 in IMPLEMENTATION.md.
///
/// This is intentionally implemented with `dart:io`'s [SecurityContext]
/// directly (no third-party pub package): it's a small amount of code,
/// avoids taking on an extra dependency for something security-critical,
/// and keeps the trust decision fully auditable in this file.
void applyCertificatePinning(
  Dio dio, {
  required List<List<int>> pinnedCertificatesPem,
}) {
  final context = createPinnedSecurityContext(pinnedCertificatesPem);
  final adapter = IOHttpClientAdapter();
  adapter.createHttpClient = () => HttpClient(context: context);
  dio.httpClientAdapter = adapter;
}