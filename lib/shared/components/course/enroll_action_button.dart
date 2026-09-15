import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';

/// "Enroll Now" CTA on course preview cards.
///
/// PRODUCT DECISION (audit 2026-09): enrollment is OUT OF RELEASE SCOPE
/// until payment integration ships — this button intentionally surfaces
/// `enrollmentComingSoon` and does NOT call enrollInCourseProvider.
/// Wiring real enrollment from here requires a new product decision (see
/// the matching note on `UserSubscriptions` in courses_provider.dart).
class EnrollActionButton extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isLoading;

  const EnrollActionButton({
    super.key,
    required this.l10n,
    this.isLoading = false,
  });

  void _onTap(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.enrollmentComingSoon),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: l10n.enrollNow,
      isLoading: isLoading,
      onPressed: isLoading ? null : () => _onTap(context),
    );
  }
}
