// test/integration/auth_integration_test.dart
// Integration tests for authentication flow

import 'dart:io';
import 'package:test/test.dart';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/auth/auth_service.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:shadow_app_backend/logging/logger.dart';

void main() {
  late DatabaseManager database;
  late String testDbPath;

  setUp(() async {
    // Create temporary test database
    testDbPath = 'data/test_auth_${DateTime.now().millisecondsSinceEpoch}.db';

    // Initialize global config
    globalConfig = ServerConfig();
    globalConfig.dbPath = testDbPath;

    // Initialize database
    database = DatabaseManager();
    await database.initialize(testDbPath);

    // Initialize logger
    await logger.initialize();
  });

  tearDown(() async {
    // Clean up test database
    try {
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error cleaning up test database: $e');
    }
  });

  group('Authentication Integration Tests', () {
    test('should complete signup flow', () async {
      final result =
          await AuthService.signup('test@example.com', 'password123');

      expect(result['success'], isTrue);
      expect(result['user'], isNotNull);
      expect(result['token'], isNotNull);

      final user = result['user'] as Map<String, dynamic>;
      expect(user['email'], equals('test@example.com'));
      expect(user['role'], equals('user'));
    });

    test('should prevent duplicate signup', () async {
      await AuthService.signup('test@example.com', 'password123');

      final result =
          await AuthService.signup('test@example.com', 'password456');

      expect(result['success'], isFalse);
      expect(result['error'], contains('already exists'));
    });

    test('should complete login flow', () async {
      // First signup
      await AuthService.signup('test@example.com', 'password123');

      // Then login
      final result = await AuthService.login('test@example.com', 'password123');

      expect(result['success'], isTrue);
      expect(result['user'], isNotNull);
      expect(result['token'], isNotNull);
    });

    test('should reject invalid login credentials', () async {
      await AuthService.signup('test@example.com', 'password123');

      final result =
          await AuthService.login('test@example.com', 'wrongpassword');

      expect(result['success'], isFalse);
      expect(result['error'], isNotNull);
    });

    test('should reject login for non-existent user', () async {
      final result =
          await AuthService.login('notexist@example.com', 'password123');

      expect(result['success'], isFalse);
      expect(result['error'], isNotNull);
    });

    test('should validate JWT tokens', () async {
      final signupResult =
          await AuthService.signup('test@example.com', 'password123');
      final accessToken = signupResult['token'] as String;

      final claims = AuthService.validateToken(accessToken);

      expect(claims, isNotNull);
      expect(claims?['sub'], isNotNull); // User ID
      expect(claims?['email'], equals('test@example.com'));
    });

    test('should reject invalid JWT tokens', () {
      final claims = AuthService.validateToken('invalid.token.here');
      expect(claims, isNull);
    });

    test('should allow token refresh', () async {
      final signupResult =
          await AuthService.signup('test@example.com', 'password123');
      final refreshToken = signupResult['token'] as String;

      final result = await AuthService.refreshToken(refreshToken);

      expect(result['success'], isTrue);
      expect(result['token'], isNotNull);
      expect(result['token'], isNot(equals(signupResult['token'])));
    });

    test('should persist user in database after signup', () async {
      await AuthService.signup('test@example.com', 'password123');

      final user = await database.getUserByEmail('test@example.com');

      expect(user, isNotNull);
      expect(user!.email, equals('test@example.com'));
      expect(user.role, equals('user'));
      expect(user.passwordHash, isNotEmpty);
    });

    test('should create users with different roles', () async {
      // Signup as regular user
      await AuthService.signup('user@example.com', 'password123');

      // Manually update to admin (would normally require admin API)
      final user = await database.getUserByEmail('user@example.com');
      await database.updateUserRole(user!.id, 'admin');

      // Verify role change
      final updatedUser = await database.getUserByEmail('user@example.com');
      expect(updatedUser!.role, equals('admin'));
    });

    test('should handle concurrent signups correctly', () async {
      final futures = List.generate(
          5, (i) => AuthService.signup('user$i@example.com', 'password$i'));

      final results = await Future.wait(futures);

      for (final result in results) {
        expect(result['success'], isTrue);
      }

      // Verify all users exist
      final users = await database.getAllUsers();
      expect(users.length, greaterThanOrEqualTo(5));
    });
  });
}
