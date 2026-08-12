import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'request_cancellation_manager.g.dart';

class RequestCancellationManager {
  CancelToken _token = CancelToken();

  /// Returns the active token. Pass to every Dio request.
  CancelToken get token => _token;

  /// Cancels all in-flight requests and creates a new token for future use.
  void cancelAll({String reason = 'logout'}) {
    _token.cancel(reason);
    _token = CancelToken(); // ready for next session
  }
}

/// Riverpod provider — singleton across the app lifecycle.
@Riverpod(keepAlive: true)
RequestCancellationManager requestCancellationManager(Ref ref) {
  return RequestCancellationManager();
}
