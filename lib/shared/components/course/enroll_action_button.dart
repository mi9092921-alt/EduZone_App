import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';

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
