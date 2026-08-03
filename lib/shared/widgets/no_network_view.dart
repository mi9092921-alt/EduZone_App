import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/arb/app_localizations.dart';

/// A modern, separated view to display when there is no network connection
/// or when a critical retry action is necessary.
class NoNetworkView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isLoading;

  const NoNetworkView({
    super.key,
    required this.message,
    required this.onRetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern Animated Container / Icon representation
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 32),

            // Error Message
            Text(
              message,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Subtitle
            Text(
              AppLocalizations.of(context)!.checkInternetConnection,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Retry Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AppButton(
                label: AppLocalizations.of(context)?.retryButton ?? 'Retry',
                isLoading: isLoading,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
