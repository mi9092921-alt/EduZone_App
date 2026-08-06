import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Error overlay shown when the embedded YouTube IFrame player reports a
/// playback error (invalid/removed video, embedding disabled, etc), with a
/// retry action.
///
/// NOTE (preserved as-is, not part of this refactor): unlike every other
/// player variant's error view, this one's strings are hardcoded Arabic
/// rather than going through `AppLocalizations` — so it won't follow the
/// app's language setting for other locales. Flagging this as a
/// pre-existing inconsistency rather than silently localizing it, since
/// that would be a behavior change beyond a pure structural split.
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
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              'خطأ في تحميل الفيديو (كود: $errorCode)',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
