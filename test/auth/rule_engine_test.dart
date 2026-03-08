// test/auth/rule_engine_test.dart
// Unit tests for permission rule engine

import 'package:test/test.dart';
import 'package:shadow_app_backend/auth/rule_engine.dart';
import 'package:shadow_app_backend/database/models.dart';

void main() {
  group('RuleEngine', () {
    group('canRead', () {
      test('should allow owner to read', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'read': ['owner']
          },
        );

        final canRead = RuleEngine.canRead('user-1', 'user', collection);
        expect(canRead, isTrue);
      });

      test('should allow admin to read', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'read': ['admin']
          },
        );

        final canRead = RuleEngine.canRead('user-2', 'admin', collection);
        expect(canRead, isTrue);
      });

      test('should deny non-owner user when only owner can read', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'read': ['owner']
          },
        );

        final canRead = RuleEngine.canRead('user-2', 'user', collection);
        expect(canRead, isFalse);
      });

      test(
          'should allow authenticated users when rule includes "authenticated"',
          () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'read': ['authenticated']
          },
        );

        final canRead = RuleEngine.canRead('user-2', 'user', collection);
        expect(canRead, isTrue);
      });

      test('should allow public read when public_read is true', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {'public_read': true},
        );

        final canRead = RuleEngine.canRead('guest', 'user', collection);
        expect(canRead, isTrue);
      });

      test('should deny read when no matching rule', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {}, // Empty rules
        );

        final canRead = RuleEngine.canRead('user-2', 'user', collection);
        expect(canRead, isFalse);
      });
    });

    group('canWrite', () {
      test('should allow owner to write', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'write': ['owner']
          },
        );

        final canWrite = RuleEngine.canWrite('user-1', 'user', collection);
        expect(canWrite, isTrue);
      });

      test('should allow admin to write', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'write': ['admin']
          },
        );

        final canWrite = RuleEngine.canWrite('user-2', 'admin', collection);
        expect(canWrite, isTrue);
      });

      test('should deny non-owner user when only owner can write', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'write': ['owner']
          },
        );

        final canWrite = RuleEngine.canWrite('user-2', 'user', collection);
        expect(canWrite, isFalse);
      });

      test(
          'should allow authenticated users when rule includes "authenticated"',
          () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'write': ['authenticated']
          },
        );

        final canWrite = RuleEngine.canWrite('user-2', 'user', collection);
        expect(canWrite, isTrue);
      });

      test('should deny write when no matching rule', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {}, // Empty rules
        );

        final canWrite = RuleEngine.canWrite('user-2', 'user', collection);
        expect(canWrite, isFalse);
      });

      test('should handle multiple allowed roles', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'write': ['owner', 'admin']
          },
        );

        expect(
            RuleEngine.canWrite('user-1', 'user', collection), isTrue); // Owner
        expect(RuleEngine.canWrite('user-2', 'admin', collection),
            isTrue); // Admin
        expect(RuleEngine.canWrite('user-3', 'user', collection),
            isFalse); // Neither
      });
    });

    group('canDelete', () {
      test('should allow owner to delete', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'delete': ['owner']
          },
        );

        final canDelete = RuleEngine.canDelete('user-1', 'user', collection);
        expect(canDelete, isTrue);
      });

      test('should allow admin to delete', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'delete': ['admin']
          },
        );

        final canDelete = RuleEngine.canDelete('user-2', 'admin', collection);
        expect(canDelete, isTrue);
      });

      test('should deny regular user delete', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {
            'delete': ['owner']
          },
        );

        final canDelete = RuleEngine.canDelete('user-2', 'user', collection);
        expect(canDelete, isFalse);
      });
    });

    group('edge cases', () {
      test('should handle null rules gracefully', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {},
        );

        expect(RuleEngine.canRead('user-2', 'user', collection), isFalse);
        expect(RuleEngine.canWrite('user-2', 'user', collection), isFalse);
        expect(RuleEngine.canDelete('user-2', 'user', collection), isFalse);
      });

      test('should handle malformed rule values', () {
        final collection = Collection(
          id: 'col-1',
          ownerId: 'user-1',
          name: 'Test Collection',
          rules: {'read': 'invalid'}, // Should be array
        );

        // Should handle gracefully and deny access
        expect(RuleEngine.canRead('user-2', 'user', collection), isFalse);
      });
    });
  });
}
