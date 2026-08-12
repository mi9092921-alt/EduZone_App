import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';

/// Shown when a non-enrolled user taps a locked (non-preview) lesson.
void showEnrollmentRequiredDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.enrollmentRequired),
      content: Text(l10n.enrollToAccessLesson),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.closeButton),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to enrollment or show options
          },
          child: Text(l10n.viewEnrollmentOptions),
        ),
      ],
    ),
  );
}
