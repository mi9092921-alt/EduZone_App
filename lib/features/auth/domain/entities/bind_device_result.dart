import 'package:equatable/equatable.dart';

/// Result of a device binding operation.
///
/// - `bound`: New device was successfully registered.
/// - `verified`: Device already exists and was re-verified.
enum BindDeviceStatus { bound, verified }

class BindDeviceResult extends Equatable {
  final BindDeviceStatus status;

  const BindDeviceResult({required this.status});

  @override
  List<Object?> get props => [status];
}
