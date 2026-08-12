import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Error overlay shown when the embedded YouTube IFrame player reports a
/// playback error (invalid/removed video, embedding disabled, etc), with a
/// retry action.
class ModernPlayerErrorOverlay extends StatelessWidget {
  final int errorCode;
  final VoidCallback onRetry;

  const ModernPlayerErrorOverlay({
    super.key,
    required this.errorCode,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              l10n.videoLoadErrorCode(errorCode),
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
