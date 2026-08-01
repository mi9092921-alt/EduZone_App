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
