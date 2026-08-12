/// Cross-feature facade for `features/downloads`.
///
/// `courses`' lesson list needs download state (progress, quality picker)
/// per lesson row. See `auth_shared.dart` for the full rationale.
library;

export '../../features/downloads/presentation/providers/downloads_provider.dart';
export '../../features/downloads/presentation/widgets/quality_selector.dart';
