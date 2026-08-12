import '../../../../core/l10n/arb/app_localizations.dart';

/// Formats total course duration in minutes into a human-readable string (e.g. "2h 5m" or "45m").
String formatCourseDuration(int totalMinutes, AppLocalizations l10n) {
  if (totalMinutes <= 0) return '';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '$h ${l10n.hours} $m ${l10n.minutes}';
  if (h > 0) return '$h ${l10n.hours}';
  return '$m ${l10n.minutes}';
}
