// test/database/models_test.dart
// Unit tests for database models

import 'package:test/test.dart';
import 'package:shadow_app_backend/database/models.dart';

void main() {
  group('User Model', () {
    test('should create user with required fields', () {
      final user = User(
        id: 'user-1',
        email: 'test@example.com',
        passwordHash: 'hashedPassword',
        role: 'user',
      );

      expect(user.id, equals('user-1'));
      expect(user.email, equals('test@example.com'));
      expect(user.passwordHash, equals('hashedPassword'));
      expect(user.role, equals('user'));
      expect(user.createdAt, isA<DateTime>());
    });

    test('should create user with admin role', () {
      final user = User(
        id: 'user-1',
        email: 'admin@example.com',
        passwordHash: 'hashedPassword',
        role: 'admin',
      );

      expect(user.role, equals('admin'));
    });

    test('should have createdAt timestamp', () {
      final before = DateTime.now();
      final user = User(
        id: 'user-1',
        email: 'test@example.com',
        passwordHash: 'hashedPassword',
        role: 'user',
      );
      final after = DateTime.now();

      expect(user.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(user.createdAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });
  });

  group('Collection Model', () {
    test('should create collection with required fields', () {
      final collection = Collection(
        id: 'col-1',
        ownerId: 'user-1',
        name: 'Test Collection',
        rules: {
          'read': ['owner', 'admin']
        },
      );

      expect(collection.id, equals('col-1'));
      expect(collection.ownerId, equals('user-1'));
      expect(collection.name, equals('Test Collection'));
      expect(collection.rules, isA<Map<String, dynamic>>());
      expect(collection.createdAt, isA<DateTime>());
      expect(collection.updatedAt, isA<DateTime>());
    });

    test('should create collection with empty rules', () {
      final collection = Collection(
        ownerId: 'user-1',
        name: 'Test Collection',
        rules: {},
      );

      expect(collection.rules, isEmpty);
    });

    test('should have timestamps', () {
      final before = DateTime.now();
      final collection = Collection(
        ownerId: 'user-1',
        name: 'Test Collection',
      );
      final after = DateTime.now();

      expect(
          collection.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(
          collection.updatedAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(collection.createdAt.isBefore(after.add(Duration(seconds: 1))),
          isTrue);
    });

    test('should generate ID if not provided', () {
      final collection = Collection(
        ownerId: 'user-1',
        name: 'Test Collection',
      );

      expect(collection.id, isNotEmpty);
      expect(collection.id.length, greaterThan(10));
    });
  });

  group('Document Model', () {
    test('should create document with required fields', () {
      final document = Document(
        id: 'doc-1',
        collectionId: 'col-1',
        ownerId: 'user-1',
        data: {'title': 'Test Document', 'content': 'Hello World'},
      );

      expect(document.id, equals('doc-1'));
      expect(document.collectionId, equals('col-1'));
      expect(document.ownerId, equals('user-1'));
      expect(document.data, isA<Map<String, dynamic>>());
      expect(document.data['title'], equals('Test Document'));
      expect(document.createdAt, isA<DateTime>());
      expect(document.updatedAt, isA<DateTime>());
    });

    test('should create document with empty data', () {
      final document = Document(
        collectionId: 'col-1',
        ownerId: 'user-1',
        data: {},
      );

      expect(document.data, isEmpty);
    });

    test('should generate ID if not provided', () {
      final document = Document(
        collectionId: 'col-1',
        ownerId: 'user-1',
        data: {'test': 'data'},
      );

      expect(document.id, isNotEmpty);
      expect(document.id.length, greaterThan(10));
    });

    test('should handle complex nested data', () {
      final document = Document(
        collectionId: 'col-1',
        ownerId: 'user-1',
        data: {
          'title': 'Complex Doc',
          'metadata': {
            'author': 'John Doe',
            'tags': ['test', 'sample'],
            'version': 1,
          },
          'content': {
            'body': 'Main content here',
            'summary': 'Short summary',
          }
        },
      );

      expect(document.data['metadata'], isA<Map>());
      expect((document.data['metadata'] as Map)['tags'], isA<List>());
    });
  });

  group('MediaBlob Model', () {
    test('should create media blob with required fields', () {
      final media = MediaBlob(
        id: 'media-1',
        documentId: 'doc-1',
        fileName: 'image.jpg',
        mimeType: 'image/jpeg',
        originalSize: 1024,
        compressedSize: 768,
        compressionAlgo: 'gzip',
        blobData: [1, 2, 3, 4, 5],
      );

      expect(media.id, equals('media-1'));
      expect(media.documentId, equals('doc-1'));
      expect(media.fileName, equals('image.jpg'));
      expect(media.mimeType, equals('image/jpeg'));
      expect(media.originalSize, equals(1024));
      expect(media.compressedSize, equals(768));
      expect(media.compressionAlgo, equals('gzip'));
      expect(media.blobData, equals([1, 2, 3, 4, 5]));
      expect(media.createdAt, isA<DateTime>());
    });

    test('should generate ID if not provided', () {
      final media = MediaBlob(
        documentId: 'doc-1',
        fileName: 'test.pdf',
        mimeType: 'application/pdf',
        originalSize: 2048,
        compressedSize: 1024,
        compressionAlgo: 'brotli',
        blobData: [],
      );

      expect(media.id, isNotEmpty);
    });

    test('should handle various MIME types', () {
      final types = [
        'image/png',
        'image/jpeg',
        'application/pdf',
        'text/plain',
        'application/json',
        'video/mp4',
      ];

      for (final type in types) {
        final media = MediaBlob(
          documentId: 'doc-1',
          fileName: 'file',
          mimeType: type,
          originalSize: 100,
          compressedSize: 80,
          compressionAlgo: 'gzip',
          blobData: [],
        );

        expect(media.mimeType, equals(type));
      }
    });
  });

  group('AuditLog Model', () {
    test('should create audit log with required fields', () {
      final log = AuditLog(
        userId: 'user-1',
        action: 'CREATE',
        resourceType: 'document',
        resourceId: 'doc-1',
        status: 'success',
      );

      expect(log.userId, equals('user-1'));
      expect(log.action, equals('CREATE'));
      expect(log.resourceType, equals('document'));
      expect(log.resourceId, equals('doc-1'));
      expect(log.status, equals('success'));
      expect(log.timestamp, isA<DateTime>());
    });

    test('should create failed audit log with error message', () {
      final log = AuditLog(
        userId: 'user-1',
        action: 'DELETE',
        resourceType: 'document',
        resourceId: 'doc-1',
        status: 'failed',
        errorMessage: 'Permission denied',
      );

      expect(log.status, equals('failed'));
      expect(log.errorMessage, equals('Permission denied'));
    });

    test('should have timestamp', () {
      final before = DateTime.now();
      final log = AuditLog(
        userId: 'user-1',
        action: 'READ',
        resourceType: 'document',
        resourceId: 'doc-1',
        status: 'success',
      );
      final after = DateTime.now();

      expect(
          log.timestamp.isAfter(before.subtract(Duration(seconds: 1))), isTrue);
      expect(log.timestamp.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('should support various action types', () {
      final actions = ['CREATE', 'READ', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT'];

      for (final action in actions) {
        final log = AuditLog(
          userId: 'user-1',
          action: action,
          resourceType: 'document',
          resourceId: 'doc-1',
          status: 'success',
        );

        expect(log.action, equals(action));
      }
    });
  });
}
