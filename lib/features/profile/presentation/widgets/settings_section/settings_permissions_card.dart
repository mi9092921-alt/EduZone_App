import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../core/permissions/permission_item.dart';
import '../../../../../design_system/design_system.dart';
import '../settings_tile.dart';
import 'settings_divider.dart';
import 'settings_permission_icon.dart';
import 'settings_permission_status_label.dart';
import 'settings_value_display.dart';

/// Content of the "Permissions" settings card: a 3-row loading skeleton
/// while permissions are being checked, or the actual list of permission
/// rows (each tappable to request/re-check that permission) once loaded.
///
/// Pure presentational widget — all data (items, statuses, loading and
/// requesting flags) and the request action are passed in, so it's
/// independently testable without a real `PermissionService`.
class SettingsPermissionsCard extends StatelessWidget {
  final bool isLoading;
  final List<PermissionItem> items;
  final Map<AppPermissionKind, PermissionStatus> statuses;
  final ValueChanged<PermissionItem> onRequestPermission;

  /// True while a native permission request is still pending:
  /// permission_handler throws a PlatformException when a second request
  /// starts before the first one settles, so every row must stay inert
  /// until then (Sentry EDUZONE-W).
  final bool isRequesting;

  const SettingsPermissionsCard({
    super.key,
    required this.isLoading,
    required this.items,
    required this.statuses,
    required this.onRequestPermission,
    this.isRequesting = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    if (isLoading && items.isEmpty) {
      return AppSkeleton(
        child: Column(
          children: List.generate(
            3,
            (index) => SettingsTile(
              icon: Icons.shield_outlined,
              title: l10n.permissionLabel,
              trailing: SettingsValueDisplay(value: l10n.permissionDenied),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Builder(
            builder: (context) {
              final item = items[index];
              final statusLabel = permissionStatusLabel(
                statuses[item.kind],
                l10n,
              );
              return SettingsTile(
                icon: iconForPermission(item.kind),
                title: item.label,
                semanticsLabel: '${item.label}, $statusLabel',
                trailing: SettingsValueDisplay(value: statusLabel),
                onTap: isRequesting ? null : () => onRequestPermission(item),
              );
            },
          ),
          if (index != items.length - 1) SettingsDivider(color: borderColor),
        ],
      ],
    );
  }
}
