// test/integration/database_integration_test.dart
// Integration tests for database operations

import 'dart:io';
import 'package:test/test.dart';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/database/models.dart';
import 'package:shadow_app_backend/auth/auth_service.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:shadow_app_backend/logging/logger.dart';

void main() {
  late DatabaseManager database;
  late String testDbPath;
  late String testUserId;

  setUp(() async {
    // Create temporary test database
    testDbPath = 'data/test_db_${DateTime.now().millisecondsSinceEpoch}.db';

    // Initialize global config
    globalConfig = ServerConfig();
    globalConfig.dbPath = testDbPath;

    // Initialize database
    database = DatabaseManager();
    await database.initialize(testDbPath);

    // Initialize logger
    await logger.initialize();

    // Create a test user
    final signupResult =
        await AuthService.signup('test@example.com', 'password123');
    final user = signupResult['user'] as Map<String, dynamic>;
    testUserId = user['id'] as String;
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

  group('Collection Operations', () {
    test('should seed bootstrap admin on initialization', () async {
      final bootstrapAdmin = await database.getUserByEmail('admin@admin.admin');

      expect(bootstrapAdmin, isNotNull);
      expect(bootstrapAdmin!.id, equals('bootstrap_admin'));
      expect(bootstrapAdmin.role, equals('admin'));
      expect(bootstrapAdmin.passwordHash, isNotEmpty);
      expect(bootstrapAdmin.passwordHash, isNot(equals('123456789')));
    });

    test('should create collection', () async {
      final collection = Collection(
        ownerId: testUserId,
        name: 'Test Collection',
        rules: {
          'read': ['owner', 'admin']
        },
      );

      await database.createCollection(collection);

      final retrieved = await database.getCollection(collection.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Test Collection'));
      expect(retrieved.ownerId, equals(testUserId));
    });

    test('should list all collections', () async {
      // Create multiple collections
      await database.createCollection(Collection(
        ownerId: testUserId,
        name: 'Collection 1',
      ));
      await database.createCollection(Collection(
        ownerId: testUserId,
        name: 'Collection 2',
      ));

      final collections = await database.getAllCollections();
      expect(collections.length, greaterThanOrEqualTo(2));
    });

    test('should update collection rules', () async {
      final collection = Collection(
        ownerId: testUserId,
        name: 'Test Collection',
        rules: {},
      );
      await database.createCollection(collection);

      final newRules = {
        'read': ['authenticated'],
        'write': ['owner']
      };
      await database.updateCollectionRules(collection.id, newRules);

      final updated = await database.getCollection(collection.id);
      expect(updated!.rules['read'], equals(['authenticated']));
      expect(updated.rules['write'], equals(['owner']));
    });
  });

  group('Document Operations', () {
    late String collectionId;

    setUp(() async {
      final collection = Collection(
        ownerId: testUserId,
        name: 'Test Collection',
      );
      await database.createCollection(collection);
      collectionId = collection.id;
    });

    test('should create document', () async {
      final document = Document(
        collectionId: collectionId,
        ownerId: testUserId,
        data: {'title': 'Test Document', 'content': 'Hello World'},
      );

      await database.createDocument(document);

      final retrieved = await database.getDocument(document.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.data['title'], equals('Test Document'));
    });

    test('should update document', () async {
      final document = Document(
        collectionId: collectionId,
        ownerId: testUserId,
        data: {'title': 'Original'},
      );
      await database.createDocument(document);

      final updated = Document(
        id: document.id,
        collectionId: collectionId,
        ownerId: testUserId,
        data: {'title': 'Updated'},
        createdAt: document.createdAt,
      );
      await database.updateDocument(updated);

      final retrieved = await database.getDocument(document.id);
      expect(retrieved!.data['title'], equals('Updated'));
    });

    test('should delete document', () async {
      final document = Document(
        collectionId: collectionId,
        ownerId: testUserId,
        data: {'title': 'To Delete'},
      );
      await database.createDocument(document);

      await database.deleteDocument(document.id);

      final retrieved = await database.getDocument(document.id);
      expect(retrieved, isNull);
    });

    test('should list documents in collection', () async {
      // Create multiple documents
      for (int i = 0; i < 5; i++) {
        await database.createDocument(Document(
          collectionId: collectionId,
          ownerId: testUserId,
          data: {'title': 'Document $i'},
        ));
      }

      final documents = await database.getCollectionDocuments(
        collectionId,
        limit: 10,
        offset: 0,
      );

      expect(documents.length, equals(5));
    });

    test('should paginate documents', () async {
      // Create 10 documents
      for (int i = 0; i < 10; i++) {
        await database.createDocument(Document(
          collectionId: collectionId,
          ownerId: testUserId,
          data: {'title': 'Document $i'},
        ));
      }

      // Get first page
      final page1 = await database.getCollectionDocuments(
        collectionId,
        limit: 3,
        offset: 0,
      );
      expect(page1.length, equals(3));

      // Get second page
      final page2 = await database.getCollectionDocuments(
        collectionId,
        limit: 3,
        offset: 3,
      );
      expect(page2.length, equals(3));

      // Verify different documents
      expect(page1.first.id, isNot(equals(page2.first.id)));
    });
  });

  group('Audit Log Operations', () {
    test('should log actions', () async {
      await database.logAction(AuditLog(
        userId: testUserId,
        action: 'CREATE',
        resourceType: 'document',
        resourceId: 'doc-1',
        status: 'success',
      ));

      final logs = await database.getAuditLog(limit: 10);
      expect(logs, isNotEmpty);
      expect(logs.first.action, equals('CREATE'));
      expect(logs.first.userId, equals(testUserId));
    });

    test('should retrieve audit log with limit', () async {
      // Create multiple log entries
      for (int i = 0; i < 20; i++) {
        await database.logAction(AuditLog(
          userId: testUserId,
          action: 'READ',
          resourceType: 'document',
          resourceId: 'doc-$i',
          status: 'success',
        ));
      }

      final logs = await database.getAuditLog(limit: 5);
      expect(logs.length, lessThanOrEqualTo(5));
    });

    test('should log failed actions with error messages', () async {
      await database.logAction(AuditLog(
        userId: testUserId,
        action: 'DELETE',
        resourceType: 'document',
        resourceId: 'doc-1',
        status: 'failed',
        errorMessage: 'Permission denied',
      ));

      final logs = await database.getAuditLog(limit: 10);
      final failedLog = logs.firstWhere((log) => log.status == 'failed');

      expect(failedLog.errorMessage, equals('Permission denied'));
    });
  });

  group('Database Statistics', () {
    test('should return database stats', () async {
      // Create some data
      final collection = Collection(ownerId: testUserId, name: 'Test');
      await database.createCollection(collection);

      await database.createDocument(Document(
        collectionId: collection.id,
        ownerId: testUserId,
        data: {'test': 'data'},
      ));

      final stats = await database.getDatabaseStats();

      expect(stats['user_count'], greaterThan(0));
      expect(stats['collection_count'], greaterThan(0));
      expect(stats['document_count'], greaterThan(0));
    });
  });

  group('User Management', () {
    test('should get all users', () async {
      final users = await database.getAllUsers();
      expect(users, isNotEmpty);
      expect(users.first.email, equals('test@example.com'));
    });

    test('should get user by ID', () async {
      final user = await database.getUserById(testUserId);
      expect(user, isNotNull);
      expect(user!.id, equals(testUserId));
    });

    test('should get user by email', () async {
      final user = await database.getUserByEmail('test@example.com');
      expect(user, isNotNull);
      expect(user!.email, equals('test@example.com'));
    });

    test('should update user role', () async {
      await database.updateUserRole(testUserId, 'admin');

      final user = await database.getUserById(testUserId);
      expect(user!.role, equals('admin'));
    });

    test('should delete user', () async {
      // Create another user to delete
      final result =
          await AuthService.signup('delete@example.com', 'password123');
      final user = result['user'] as Map<String, dynamic>;
      final deleteUserId = user['id'] as String;

      await database.deleteUser(deleteUserId);

      final retrieved = await database.getUserById(deleteUserId);
      expect(retrieved, isNull);
    });
  });
}
