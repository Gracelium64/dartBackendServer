// test/auth/password_utils_test.dart
// Unit tests for password hashing and validation utilities

import 'package:test/test.dart';
import 'package:shadow_app_backend/auth/password_utils.dart';

void main() {
  group('PasswordUtils', () {
    group('hashPassword', () {
      test('should hash a password', () {
        final password = 'testPassword123';
        final hashed = PasswordUtils.hashPassword(password);

        expect(hashed, isNotEmpty);
        expect(hashed.length, greaterThan(50));
        expect(hashed, isNot(equals(password)));
      });

      test('should produce different hashes for same password (due to salt)',
          () {
        final password = 'testPassword123';
        final hash1 = PasswordUtils.hashPassword(password);
        final hash2 = PasswordUtils.hashPassword(password);

        expect(hash1, isNot(equals(hash2))); // Different salts
      });

      test('should handle empty password', () {
        final hashed = PasswordUtils.hashPassword('');
        expect(hashed, isNotEmpty);
      });

      test('should handle special characters', () {
        final password = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
        final hashed = PasswordUtils.hashPassword(password);

        expect(hashed, isNotEmpty);
      });

      test('should handle unicode characters', () {
        final password = 'パスワード🔐';
        final hashed = PasswordUtils.hashPassword(password);

        expect(hashed, isNotEmpty);
      });
    });

    group('verifyPassword', () {
      test('should verify correct password', () {
        final password = 'testPassword123';
        final hashed = PasswordUtils.hashPassword(password);

        final isValid = PasswordUtils.verifyPassword(password, hashed);
        expect(isValid, isTrue);
      });

      test('should reject incorrect password', () {
        final password = 'testPassword123';
        final hashed = PasswordUtils.hashPassword(password);

        final isValid = PasswordUtils.verifyPassword('wrongPassword', hashed);
        expect(isValid, isFalse);
      });

      test('should reject empty password against valid hash', () {
        final password = 'testPassword123';
        final hashed = PasswordUtils.hashPassword(password);

        final isValid = PasswordUtils.verifyPassword('', hashed);
        expect(isValid, isFalse);
      });

      test('should handle case sensitivity', () {
        final password = 'TestPassword123';
        final hashed = PasswordUtils.hashPassword(password);

        final isValid = PasswordUtils.verifyPassword('testpassword123', hashed);
        expect(isValid, isFalse);
      });

      test('should verify password with special characters', () {
        final password = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
        final hashed = PasswordUtils.hashPassword(password);

        final isValid = PasswordUtils.verifyPassword(password, hashed);
        expect(isValid, isTrue);
      });
    });

    group('edge cases', () {
      test('should handle very long passwords', () {
        final password = 'a' * 1000;
        final hashed = PasswordUtils.hashPassword(password);

        expect(hashed, isNotEmpty);
        expect(PasswordUtils.verifyPassword(password, hashed), isTrue);
      });

      test('should handle passwords with newlines', () {
        final password = 'pass\nword\n123';
        final hashed = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword(password, hashed), isTrue);
      });

      test('should handle passwords with null bytes (if applicable)', () {
        final password = 'pass\u0000word';
        final hashed = PasswordUtils.hashPassword(password);

        expect(PasswordUtils.verifyPassword(password, hashed), isTrue);
      });
    });
  });
}
