import 'package:app/shared/models/account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStatus.fromString', () {
    test('maps every known DB/RPC string to its enum value', () {
      expect(AccountStatus.fromString('active'), AccountStatus.active);
      expect(AccountStatus.fromString('inactive'), AccountStatus.inactive);
      expect(AccountStatus.fromString('suspended'), AccountStatus.suspended);
      expect(
        AccountStatus.fromString('account_suspended'),
        AccountStatus.suspended,
      );
      expect(AccountStatus.fromString('locked'), AccountStatus.locked);
      expect(
        AccountStatus.fromString('account_locked'),
        AccountStatus.locked,
      );
      expect(AccountStatus.fromString('banned'), AccountStatus.banned);
      expect(
        AccountStatus.fromString('account_banned'),
        AccountStatus.banned,
      );
      expect(
        AccountStatus.fromString('maintenance'),
        AccountStatus.maintenance,
      );
      expect(
        AccountStatus.fromString('maintenance_mode'),
        AccountStatus.maintenance,
      );
      expect(
        AccountStatus.fromString('unauthenticated'),
        AccountStatus.unauthenticated,
      );
      expect(
        AccountStatus.fromString('auth_required'),
        AccountStatus.unauthenticated,
      );
      expect(AccountStatus.fromString('appLocked'), AccountStatus.appLocked);
      expect(
        AccountStatus.fromString('app_locked'),
        AccountStatus.appLocked,
      );
      // DENIAL-SESSION-CLEANUP (2026-09-25): previously-unmapped denial
      // reasons are now explicit instead of falling through to
      // unrecognized, so the session teardown rule in auth_provider can
      // clear the stored JWT for them.
      expect(AccountStatus.fromString('deleted'), AccountStatus.deleted);
      expect(
        AccountStatus.fromString('user_not_found'),
        AccountStatus.deleted,
      );
      expect(
        AccountStatus.fromString('account_inactive'),
        AccountStatus.inactive,
      );
      expect(
        AccountStatus.fromString('token_version_mismatch'),
        AccountStatus.unauthenticated,
      );
    });

    // SECURITY REGRESSION: the default case here used to be
    // `AccountStatus.active`. Since `checkStudentAppAccess()` only calls
    // `fromString` after the server has already returned
    // `allowed: false`, that default silently converted an explicit
    // denial into "active" the moment the server sent any `reason`
    // string this client's enum didn't cover -- which
    // `UserAccess.isAllowed` (`status == AccountStatus.active`) then
    // read as full access. This pins the fail-closed default so it
    // can never regress back to fail-open.
    test(
        'falls back to unrecognized (fail-closed) for any unknown '
        'string, never to active', () {
      for (final unknownReason in [
        'some_brand_new_server_side_reason',
        '',
        'ACTIVE', // case-sensitive mismatch is also "unknown" here
      ]) {
        expect(
          AccountStatus.fromString(unknownReason),
          AccountStatus.unrecognized,
          reason: '"$unknownReason" must not resolve to active',
        );
      }
    });

    test('unrecognized round-trips through toDbString without throwing', () {
      expect(AccountStatus.unrecognized.toDbString, 'unrecognized');
    });

    test('only maintenance and app_locked keep the session', () {
      // DENIAL-SESSION-CLEANUP (2026-09-25): every denial except the two
      // "keep-session restriction" screens must trigger the local session
      // teardown in auth_provider. Pin the predicate so a newly added enum
      // value cannot silently default to keep-session.
      for (final status in AccountStatus.values) {
        final keeps = status.isKeepSessionRestriction;
        expect(
          keeps,
          status == AccountStatus.maintenance ||
              status == AccountStatus.appLocked,
          reason: '$status must respect the keep-session matrix',
        );
      }
    });
  });
}
