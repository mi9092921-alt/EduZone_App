import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserAccess Entity', () {
    test('isAllowed returns true when status is active', () {
      const access = UserAccess(status: AccountStatus.active);
      expect(access.isAllowed, isTrue);
    });

    test('isAllowed returns false when status is not active', () {
      const lockedAccess = UserAccess(status: AccountStatus.locked);
      const bannedAccess = UserAccess(status: AccountStatus.banned);
      const unauthAccess = UserAccess.unauthenticated();

      expect(lockedAccess.isAllowed, isFalse);
      expect(bannedAccess.isAllowed, isFalse);
      expect(unauthAccess.isAllowed, isFalse);
    });

    // Regression test for the fail-open authorization bug: AccountStatus
    // .fromString used to default any unrecognized reason string to
    // `active`, so an explicit server denial (`allowed: false`) carrying
    // a `reason` this client didn't know about (e.g. a new server-side
    // reason, or `token_version_mismatch`, which is a real value the
    // Realtime security channel already sends) silently became
    // `isAllowed == true`. See AccountStatus.unrecognized's doc comment.
    test(
        'isAllowed returns false for an unrecognized status (fail-closed, '
        'not fail-open)', () {
      final access = UserAccess(
        status: AccountStatus.fromString('some_future_denial_reason'),
      );

      expect(access.status, AccountStatus.unrecognized);
      expect(
        access.isAllowed,
        isFalse,
        reason: 'an unrecognized denial reason must never be treated as '
            'active/allowed access',
      );
    });

    test('unauthenticated factory creates correct state', () {
      const access = UserAccess.unauthenticated();

      expect(access.status, AccountStatus.unauthenticated);
      expect(access.message, isNull);
      expect(access.until, isNull);
      expect(access.endsAt, isNull);
    });

    test('supports value equality', () {
      const access1 = UserAccess(
        status: AccountStatus.suspended,
        message: 'Wait',
      );
      const access2 = UserAccess(
        status: AccountStatus.suspended,
        message: 'Wait',
      );

      expect(access1, equals(access2));
    });
  });
}
