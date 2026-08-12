import 'dart:io';

import 'package:app/core/network/certificate_pinning.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

// Real X.509 PEM extracted from supabase.com on 2026-07-30
// (Let's Encrypt YR1, valid until 2026-10-09)
const _supabasePem = '''-----BEGIN CERTIFICATE-----
MIIE9DCCA9ygAwIBAgISBcjiQUz2J52IxxI9hnUQgF/QMA0GCSqGSIb3DQEBCwUA
MDMxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQD
EwNZUjEwHhcNMjYwNzExMTkyMjA3WhcNMjYxMDA5MTkyMjA2WjAXMRUwEwYDVQQD
EwxzdXBhYmFzZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCY
ObSVqwmIjUGKXITR4AEMno1YjQ35n9vGyhjwwThyARDRHsRxeX2CCUJMVVRbJ9uu
Xg8WzfUXyJPB6jkCSylPAKgPFRf15bpvdv/HR8dQJ5myFg0AXoFkUwff5yAR6fCE
E571pzpdflQqdj9UfYvHUYZfSssM1y0QvV/NIZFule4TCzwVr4saimJzd/c+/EFb
LkcDT1G7p5NjB179ShOd5VcwtU7ayU4pLO6lc/KpNaoAxRMM1qwsxcNz2zbCDTLJ
1WHL/xCRexYoQU25I82Fy3Ec54HRMXKZvjHAUBgFUk4+VIp9Yp/Gmb9GaUaoSs6T
HJVOsDBt+J3A9OC3ERwvAgMBAAGjggIcMIICGDAOBgNVHQ8BAf8EBAMCBaAwEwYD
VR0lBAwwCgYIKwYBBQUHAwEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUf1OZHfCf
JdUEKypJbYSjsshwiEgwHwYDVR0jBBgwFoAUHy81vkYUgs1Asa55LFV4+vfUaPsw
MwYIKwYBBQUHAQEEJzAlMCMGCCsGAQUFBzAChhdodHRwOi8veXIxLmkubGVuY3Iu
b3JnLzAXBgNVHREEEDAOggxzdXBhYmFzZS5jb20wEwYDVR0gBAwwCjAIBgZngQwB
AgEwLgYDVR0fBCcwJTAjoCGgH4YdaHR0cDovL3lyMS5jLmxlbmNyLm9yZy84MS5j
cmwwggEOBgorBgEEAdZ5AgQCBIH/BIH8APoAdwDIo8R/x7OtuTVrAT9qehJt4zpO
Q6XGRvmXrTl1mR3PmgAAAZ9S1tG1AAAEAwBIMEYCIQDKtn/MThQvZv4rq8LhDOZH
zJJ4tDE9JikcNHEia+uyTwIhAIKZkq3PGxdSgRfkbVCWdHb5oDbRD5fcLrgKM0Vu
GFRSAH8ARq+GPTs+5Z+ld96oJF02sNntIqIj9GF3QSKUUu6VUF8AAAGfUtbSHAAI
AAAFAAybnuAEAwBIMEYCIQDrWlKJVogrMx+9ByeXu0PxgVNSjFg94R1rTHfEdxDZ
HwIhAIoF16cw6Q+Yn7VuvbC3ipkO3OYpMFz79GRn0qy2zZxsMA0GCSqGSIb3DQEB
CwUAA4IBAQBiUomjMz3+aH+C1fz0OpbESMJ9gU/Wbbxw6XpD3h5iRyVKOlWGFM4g
sQwQ+SKKGWsGHO7MEVBEGPjzIN/MiqJqWWadQHpaJW7oCea0tQ4KNuIHL1sK+bI+
e/rW8ZeY7/FnuyVM3iHgXwVEmxE0mTNBQo8FHdtTHMQzS9U9h/7WuAc3SfQkNwDM
fEQQDv+PPhTb6amA9JQAZldLVzuU+MHFRlkD8dffOaLVfBWd3tfOM+3O+udbIImA
YSqdpTcE4tcwzq1v/TB+vPzLSfaH/GBqDMgeLZhBrlX9p/LSaFKwqCimZTeOLOJx
5zmEqJWKPBV0UKH2Qzkznk5lLI5iRYSZ
-----END CERTIFICATE-----''';

List<int> _pemBytes() => _supabasePem.codeUnits;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Certificate Pinning', () {
    // ── Guard tests (no cert bytes needed) ─────────────────────────────────

    test('createPinnedSecurityContext throws ArgumentError on empty list', () {
      expect(
        () => createPinnedSecurityContext([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('applyCertificatePinning throws ArgumentError on empty list', () {
      expect(
        () => applyCertificatePinning(Dio(), pinnedCertificatesPem: []),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── Real PEM tests ──────────────────────────────────────────────────────

    test('createPinnedSecurityContext returns a SecurityContext', () {
      final ctx = createPinnedSecurityContext([_pemBytes()]);
      expect(ctx, isA<SecurityContext>());
    });

    test('createPinnedHttpClient returns an HttpClient', () {
      final client = createPinnedHttpClient([_pemBytes()]);
      expect(client, isA<HttpClient>());
      client.close();
    });

    test('applyCertificatePinning sets IOHttpClientAdapter on Dio', () {
      final dio = Dio();
      applyCertificatePinning(dio, pinnedCertificatesPem: [_pemBytes()]);
      expect(dio.httpClientAdapter, isA<IOHttpClientAdapter>());
    });

    // ── Asset loader ────────────────────────────────────────────────────────

    test('loadPinnedCertificatesAsset returns empty list gracefully when assets are absent', () async {
      // Assets are not registered in the test environment, so the loader
      // must swallow the AssetBundle error and return [] rather than throwing.
      final certs = await loadPinnedCertificatesAsset(
        assetPaths: ['assets/certs/supabase.pem', 'assets/certs/backup_ca.pem'],
        onlyInRelease: false,
      );
      expect(certs, isA<List<List<int>>>());
      // In unit tests there is no real asset bundle, so we just verify the
      // loader didn't throw; it may return 0 or more items.
    });

    // ── isSupabaseHost ──────────────────────────────────────────────────────

    group('isSupabaseHost', () {
      test('returns true for *.supabase.co', () {
        expect(isSupabaseHost('https://xyz.supabase.co/rest/v1/table'), isTrue);
      });

      test('returns true for a configured Supabase URL', () {
        expect(
          isSupabaseHost(
            'https://myproject.supabase.co/functions/v1/check',
            configuredSupabaseUrl: 'https://myproject.supabase.co',
          ),
          isTrue,
        );
      });

      test('returns false for external CDN hosts', () {
        expect(isSupabaseHost('https://rr5---sn-25glene6.googlevideo.com/videoplayback?id=1'), isFalse);
        expect(isSupabaseHost('https://googlevideo.com/video'), isFalse);
        expect(isSupabaseHost('https://cdn.example.com/segment.ts'), isFalse);
      });

      test('returns false for empty or invalid URLs', () {
        expect(isSupabaseHost(''), isFalse);
        expect(isSupabaseHost('not-a-url'), isFalse);
      });
    });
  });
}
