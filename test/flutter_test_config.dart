import 'dart:async';

/// Runs once before ALL tests in this project.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
