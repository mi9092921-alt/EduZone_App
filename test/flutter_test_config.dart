import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs once before ALL tests in this project.
///
/// GoogleFonts normally tries to fetch/cache font files at runtime, which
/// is non-deterministic across machines/CI runs (network, font cache state)
/// and is the confirmed cause of golden-test flakiness for any widget that
/// renders Arabic text (Cairo font) — e.g. settings_tile_golden_test.dart's
/// "with Subtitle and Trailing" case. Disabling runtime fetching forces a
/// deterministic fallback font, identical on every machine.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
