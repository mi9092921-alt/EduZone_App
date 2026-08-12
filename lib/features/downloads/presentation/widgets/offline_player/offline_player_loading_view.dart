import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Loading placeholder shown while [OfflinePlayerWrapper] is decrypting the
/// downloaded file / starting the streaming proxy.
///
/// Pure presentational widget: no dependency on the player, decryption
/// service, or any mutable state, so it is fully unit-testable in isolation.
class OfflinePlayerLoadingView extends StatelessWidget {
  final double aspectRatio;

  const OfflinePlayerLoadingView({super.key, required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.offlineModeLabel,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
