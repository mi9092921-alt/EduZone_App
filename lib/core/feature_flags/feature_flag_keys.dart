/// Typed registry of every remote feature flag the student app consumes.
///
/// One enum entry per flag — never reference a flag by its raw string in
/// feature code; always go through [FeatureFlagKey] so lookups, cache keys,
/// and tests are compile-time checked.
///
/// Contract with the canonical server-side evaluator
/// (`public.evaluate_feature_flags(text[])`, supabase/schema/07_functions.sql):
///
/// * The app sends only flag KEYS. The evaluator derives user/tenant from the
///   JWT server-side — the client never passes (and cannot spoof) targeting
///   parameters.
/// * A row returned with `version >= 1` means the flag is registered in the
///   canonical `feature_flags` table and the server verdict is authoritative.
/// * A row with `version == 0` (or a missing row) means the flag is NOT
///   registered server-side — the client falls back to [defaultValue], which
///   MUST equal the behavior currently in production so that shipping the app
///   and registering the flag are independently safe operations.
///
/// Feature flags are configuration, NOT authorization. Gating a UI affordance
/// behind a flag never replaces server-side authn/authz/RLS/entitlement
/// checks; see docs/FEATURE_FLAGS.md ("Security boundary").
enum FeatureFlagKey {
  /// Controls the "direct player" (player4) entry in the lesson
  /// player-choice sheet (courses feature). Default `true` = the option is
  /// offered, exactly as before this flag existed. Registered server-side,
  /// it lets support kill the experimental direct-player backend remotely
  /// (per-student rollout / tenant override / global kill switch) without an
  /// app release — the same class of removal that already happened once for
  /// the earlier WebView-based proxy player.
  ///
  /// NOTE: the server row predates the dot-free key convention — it was
  /// registered as `player.direct_player`. The dashboard-side rename to
  /// `player_direct_player` must ship with (before or together with) the
  /// first build carrying this serverKey; until then the evaluator returns
  /// version 0 and the client default (true) applies.
  playerDirectPlayer(
    'player_direct_player',
    defaultValue: true,
    description:
        'Direct (player4) option in the lesson player-choice sheet. '
        'false hides the option; the other player choices remain.',
  ),

  /// Controls the "continue watching" resume card carousel on the home tab.
  /// Default `true` = the section renders, exactly as before this flag
  /// existed. Registered server-side, it lets support hide the section
  /// remotely (per-student rollout / tenant override / global kill switch)
  /// without an app release — including its provider fetch, so a killed
  /// backend is not queried either.
  homeResumeCarousel(
    'home_resume_carousel',
    defaultValue: true,
    description:
        'Resume card carousel on the home tab. false skips the section '
        'entirely, including its loading/error states.',
  ),

  /// Controls the YouTube entry in the lesson player-choice sheet (courses
  /// feature). Default `true` = the option is offered, exactly as before
  /// this flag existed. Same kill-switch model as [playerDirectPlayer].
  playerYoutube(
    'player_youtube',
    defaultValue: true,
    description:
        'YouTube option in the lesson player-choice sheet. '
        'false hides the option; the other player choices remain.',
  ),

  /// Controls the "modern" entry in the lesson player-choice sheet (courses
  /// feature). Default `true` = the option is offered, exactly as before
  /// this flag existed. Same kill-switch model as [playerDirectPlayer].
  playerModern(
    'player_modern',
    defaultValue: true,
    description:
        'Modern player option in the lesson player-choice sheet. '
        'false hides the option; the other player choices remain.',
  ),

  /// Controls every downloads UI affordance in the app: the downloads entry
  /// on the courses tab, the per-lesson download buttons, and the downloads
  /// manager screen itself. Default `true` = current behavior. Hiding the
  /// affordances is NOT an authorization boundary — download/storage
  /// operations keep their own enforcement layers; the flag only removes
  /// the UI surface.
  coursesDownloads(
    'courses_downloads',
    defaultValue: true,
    description:
        'Downloads UI affordances (courses-tab entry, per-lesson download '
        'buttons, downloads screen). false hides them all.',
  );

  const FeatureFlagKey(
    this.serverKey, {
    required this.defaultValue,
    required this.description,
  });

  /// Key exactly as stored in `public.feature_flags.key`. MUST satisfy the
  /// database constraint `chk_feature_flags_key_format`:
  /// `^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$`, length 2..128.
  ///
  /// The dashboard admin UI is stricter than the DB (its create/edit form
  /// only accepts `^[a-z][a-z0-9_]*$` — lowercase letters, digits,
  /// underscores; dots are stripped while typing), so keys in this registry
  /// use the dot-free `<area>_<capability>` form and can be fully managed
  /// from the product UI.
  final String serverKey;

  /// Client-side value when the server has not spoken for this flag
  /// (unregistered, offline cold start with no cache, malformed response).
  /// MUST mirror the behavior already in production.
  final bool defaultValue;

  /// Human-readable purpose, kept in code so a reviewer sees what a flag
  /// gates without leaving the repo.
  final String description;

  static final Map<String, FeatureFlagKey> _byServerKey = {
    for (final key in FeatureFlagKey.values) key.serverKey: key,
  };

  /// Lookup by server key; returns null for keys the app does not know
  /// (the server may have flags registered for newer app versions).
  static FeatureFlagKey? fromServerKey(String serverKey) =>
      _byServerKey[serverKey];

  /// All keys the app should evaluate in one batch. The canonical evaluator
  /// rejects batches larger than 100 keys
  /// (`evaluate_feature_flags` raises ERRCODE 22023), so the registry must
  /// stay under that — enforced by a unit test, not by convention.
  static List<FeatureFlagKey> get all => FeatureFlagKey.values;

  /// The database-side key-format invariant, mirrored here so a regression
  /// is caught by a unit test at PR time instead of by a failed INSERT in
  /// production. Keep in sync with `chk_feature_flags_key_format` in
  /// supabase/schema/04_constraints.sql.
  static bool isValidServerKey(String key) {
    final pattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$');
    return key.length >= 2 && key.length <= 128 && pattern.hasMatch(key);
  }
}
