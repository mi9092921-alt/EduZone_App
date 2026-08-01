import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser Entity', () {
    test(
      'displayName returns full name when both first and last name are provided',
      () {
        const user = AppUser(
          id: '1',
          email: 'test@example.com',
          firstName: 'John',
          lastName: 'Doe',
        );
        expect(user.displayName, 'John Doe');
      },
    );

    test('displayName returns firstName when only firstName is provided', () {
      const user = AppUser(
        id: '1',
        email: 'test@example.com',
        firstName: 'John',
      );
      expect(user.displayName, 'John');
    });

    test('displayName returns email prefix when no names are provided', () {
      const user = AppUser(id: '1', email: 'student123@example.com');
      expect(user.displayName, 'student123');
    });

    test('initials returns first letters of first and last name', () {
      const user = AppUser(
        id: '1',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
      );
      expect(user.initials, 'JD');
    });

    test(
      'initials returns first letter of firstName when only firstName is provided',
      () {
        const user = AppUser(
          id: '1',
          email: 'test@example.com',
          firstName: 'John',
        );
        expect(user.initials, 'J');
      },
    );

    test(
      'initials returns first letter of email when no names are provided',
      () {
        const user = AppUser(id: '1', email: 'student123@example.com');
        expect(user.initials, 'S');
      },
    );

    test('supports value equality', () {
      const user1 = AppUser(id: '1', email: 'a@b.com');
      const user2 = AppUser(id: '1', email: 'a@b.com');
      expect(user1, equals(user2));
    });
  });
}
