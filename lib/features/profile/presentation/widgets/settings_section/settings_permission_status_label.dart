import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';

/// Localized display label for a permission's current [PermissionStatus]
/// ("Granted" / "Denied" / "Permanently denied"). Treats a missing status
/// (not yet checked) the same as denied, matching the original's
/// `?? PermissionStatus.denied` fallback.
///
/// Pure function — didn't depend on any widget state in the original
/// `_getPermissionStatusLabel`, so it moves out unchanged and is now
/// directly unit-testable.
String permissionStatusLabel(PermissionStatus? status, AppLocalizations l10n) {
  final resolved = status ?? PermissionStatus.denied;
  if (resolved.isGranted) return l10n.permissionGranted;
  if (resolved.isPermanentlyDenied) return l10n.permissionPermanentlyDenied;
  return l10n.permissionDenied;
}
