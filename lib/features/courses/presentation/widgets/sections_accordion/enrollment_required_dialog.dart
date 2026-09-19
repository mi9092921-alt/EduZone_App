import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';

/// Shown when a non-enrolled user taps a locked (non-preview) lesson.
void showEnrollmentRequiredDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) => ConfirmDialog(
      title: l10n.enrollmentRequired,
      description: l10n.enrollToAccessLesson,
      confirmLabel: l10n.viewEnrollmentOptions,
      cancelLabel: l10n.closeButton,
      onConfirm: () {
        Navigator.pop(context);
        // Navigate to enrollment or show options
      },
    ),
  );
}
