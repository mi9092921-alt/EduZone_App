import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized [FlutterSecureStorage] configuration for the whole app.
///
/// AUTH-00 audit finding (EduZone_Authentication_Session_Security_Architecture.md,
/// "Secure Session Storage"): every call site in this codebase previously
/// constructed `const FlutterSecureStorage()` with no explicit options,
/// silently relying on the plugin's platform defaults — the same decision
/// re-made (uninspected) at ~10 separate call sites instead of being one
/// deliberate, reviewed choice. This file makes that choice explicit and
/// shared.
///
/// ── iOS ──────────────────────────────────────────────────────────────────
/// Pins `KeychainAccessibility.first_unlock_this_device`. Keychain
/// accessibility is a write-time attribute — existing items keep whatever
/// accessibility they were written with until the next write — so
/// introducing this is safe with no migration step; it only takes effect
/// for values written from this point on. It:
///   (a) denies Keychain access before the device's first unlock following
///       a reboot, closing a narrow pre-unlock extraction window, and
///   (b) excludes the item from iCloud Keychain / device-to-device
///       transfer — a session token or offline-download key must never
///       silently reappear on a different physical device.
///
/// ── Android ──────────────────────────────────────────────────────────────
/// Intentionally left at the plugin default (`encryptedSharedPreferences:
/// false`) rather than flipping to the newer `EncryptedSharedPreferences`
/// (Jetpack Security) backend here. That flag changes the on-disk storage
/// *format*, not just an access policy: switching it for an app already
/// installed on real devices would make every previously-written key
/// unreadable on next launch (session token, offline-download keys, HMAC
/// key, device install ID) with no migration path — effectively a silent
/// forced logout and loss of offline downloads for every existing install.
/// That is a real, separate, larger change (needs a read-old/write-new
/// migration or a one-time re-provision flow) and is intentionally out of
/// scope for this pass. Declared explicitly below (rather than omitted)
/// so the decision is visible and trackable as a follow-up, not silently
/// re-decided by whatever the plugin's default happens to be in a future
/// dependency bump.
const IOSOptions hardenedIOSOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

// Deliberately matches the plugin default; see doc comment above for why
// this is not flipped to encryptedSharedPreferences: true.
const AndroidOptions hardenedAndroidOptions = AndroidOptions();

/// Shared, hardened [FlutterSecureStorage] instance. Use this instead of
/// constructing `FlutterSecureStorage()` directly so every call site gets
/// the same deliberate, documented configuration above.
const FlutterSecureStorage hardenedSecureStorage = FlutterSecureStorage(
  iOptions: hardenedIOSOptions,
);
