// lib/database/db_manager.dart
// SQLite database manager - handles connections and query execution
// Explanation for Flutter Developers:
// This is similar to your database helper in Flutter. It manages the connection
// to SQLite and provides methods for common database operations (CRUD).
// In Flutter, you might extend SQLiteOpenHelper or use sqflite.Database;
// here we use sqlite3.Database.

import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'models.dart';
import 'migrations.dart';
import '../auth/password_utils.dart';
import '../config.dart';
import '../logging/logger.dart';

extension RowToMap on Row {
  Map<String, Object?> toMap() {
    return Map<String, Object?>.from(this);
  }
}

/// Main database manager class
/// Handles all database connections, queries, and transactions
class DatabaseManager {
  late Database _db;
  static DatabaseManager? _instance;
  String _auditActor = 'system';

  /// Singleton pattern - ensure only one database connection
  factory DatabaseManager() {
    _instance ??= DatabaseManager._internal();
    return _instance!;
  }

  DatabaseManager._internal();

  /// Set the actor identity used by DB-level audit entries.
  ///
  /// Server runtime uses the default `system`, while interactive admin console
  /// can set `admin_console` for operation attribution.
  void setAuditActor(String actorId) {
    final normalized = actorId.trim();
    _auditActor = normalized.isEmpty ? 'system' : normalized;
  }

  /// Initialize and open database connection
  Future<void> initialize(String dbPath) async {
    print('[DB] Initializing database at $dbPath...');

    // Create directory if needed
    final dir = path.dirname(dbPath);
    if (!await Directory(dir).exists()) {
      await Directory(dir).create(recursive: true);
      print('[DB] Created database directory: $dir');
    }

    // Open or create database
    _db = sqlite3.open(dbPath);
    print('[DB] Database opened');

    // Enable Write-Ahead Logging for concurrency
    if (globalConfig.enableWal) {
      _db.execute('PRAGMA journal_mode=WAL');
      print('[DB] Enabled Write-Ahead Logging (WAL) for better concurrency');
    }

    // Enable foreign keys
    _db.execute('PRAGMA foreign_keys=ON');
    print('[DB] Foreign keys enabled');

    // Create schema if new database
    SchemaMigration.createTables(_db);
    SchemaMigration.runMigrations(_db);
    _ensureServiceUsers();

    // Keep the global DB handle in sync for services that use it directly.
    database = this;

    print('[DB] Database initialized successfully');
  }

  void _ensureServiceUsers() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bootstrapAdminHash = PasswordUtils.hashPassword('123456789');
    final stmt = _db.prepare('''
      INSERT OR IGNORE INTO users (id, email, password_hash, role, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');

    final serviceUsers = <List<Object?>>[
      ['system', 'system@shadow.local', 'service-account', 'admin', now, now],
      [
        'admin_console',
        'admin_console@shadow.local',
        'service-account',
        'admin',
        now,
        now,
      ],
      [
        'anonymous',
        'anonymous@shadow.local',
        'service-account',
        'user',
        now,
        now,
      ],
      [
        'bootstrap_admin',
        'admin@admin.admin',
        bootstrapAdminHash,
        'admin',
        now,
        now,
      ],
    ];

    for (final row in serviceUsers) {
      stmt.execute(row);
    }
    stmt.dispose();
    // Ensure some default collections exist so clients can create documents
    // immediately after signup (e.g. 'users', 'notes'). Use 'system' as owner.
    try {
      final defaultCollections = [
        'users',
        'notes',
      ];
      for (final name in defaultCollections) {
        final existing = getCollectionByName(name);
        // getCollectionByName returns a Future; check and create if missing
        existing.then((c) async {
          if (c == null) {
            final collection = Collection(ownerId: 'system', name: name);
            await createCollection(collection);
          }
        });
      }
    } catch (e) {
      print('[DB] Failed to ensure default collections: $e');
    }
  }

  /// Close database connection
  void close() {
    _db.dispose();
    print('[DB] Database connection closed');
  }

  // === USER OPERATIONS ===

  /// Create a new user
  Future<User> createUser(User user) async {
    try {
      final stmt = _db.prepare('INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)');
      stmt.execute([
        user.id,
        user.email,
        user.passwordHash,
        user.role,
        user.createdAt.millisecondsSinceEpoch,
        user.updatedAt.millisecondsSinceEpoch,
      ]);
      stmt.dispose();

      print('[DB] User created: ${user.email}');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'user',
        resourceId: user.id,
        status: 'success',
      );
      return user;
    } catch (e) {
      print('[DB ERROR] Failed to create user: $e');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'user',
        resourceId: user.id,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final stmt = _db.prepare('SELECT * FROM users WHERE email = ?');
      final rows = stmt.select([email]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      return User.fromJson(rows.first.toMap());
    } catch (e) {
      print('[DB ERROR] Failed to get user by email: $e');
      rethrow;
    }
  }

  /// Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final stmt = _db.prepare('SELECT * FROM users WHERE id = ?');
      final rows = stmt.select([userId]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      return User.fromJson(rows.first.toMap());
    } catch (e) {
      print('[DB ERROR] Failed to get user by ID: $e');
      rethrow;
    }
  }

  /// Get all users (admin only)
  Future<List<User>> getAllUsers() async {
    try {
      final rows = _db.select('SELECT * FROM users ORDER BY created_at DESC');
      return rows.map((r) => User.fromJson(r.toMap())).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get all users: $e');
      rethrow;
    }
  }

  /// Update a user's role
  Future<User?> updateUserRole(String userId, String role) async {
    try {
      final normalizedRole = role.trim().toLowerCase();

      if (normalizedRole != 'user' && normalizedRole != 'admin') {
        throw ArgumentError('Role must be either "user" or "admin"');
      }

      final stmt = _db.prepare('''
        UPDATE users
        SET role = ?, updated_at = ?
        WHERE id = ?
      ''');
      stmt.execute([
        normalizedRole,
        DateTime.now().millisecondsSinceEpoch,
        userId,
      ]);
      stmt.dispose();

      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_role',
        resourceId: userId,
        status: 'success',
      );

      return await getUserById(userId);
    } catch (e) {
      print('[DB ERROR] Failed to update user role: $e');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_role',
        resourceId: userId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Update a user's email address.
  Future<User?> updateUserEmail(String userId, String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) {
        throw ArgumentError('Email is required');
      }

      final existingUser = await getUserByEmail(normalizedEmail);
      if (existingUser != null && existingUser.id != userId) {
        throw StateError('Email is already in use');
      }

      final stmt = _db.prepare('''
        UPDATE users
        SET email = ?, updated_at = ?
        WHERE id = ?
      ''');
      stmt.execute([
        normalizedEmail,
        DateTime.now().millisecondsSinceEpoch,
        userId,
      ]);
      stmt.dispose();

      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_email',
        resourceId: userId,
        status: 'success',
      );

      return await getUserById(userId);
    } catch (e) {
      print('[DB ERROR] Failed to update user email: $e');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_email',
        resourceId: userId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Update a user's password hash.
  Future<User?> updateUserPasswordHash(
      String userId, String passwordHash) async {
    try {
      if (passwordHash.trim().isEmpty) {
        throw ArgumentError('Password hash is required');
      }

      final stmt = _db.prepare('''
        UPDATE users
        SET password_hash = ?, updated_at = ?
        WHERE id = ?
      ''');
      stmt.execute([
        passwordHash,
        DateTime.now().millisecondsSinceEpoch,
        userId,
      ]);
      stmt.dispose();

      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_password',
        resourceId: userId,
        status: 'success',
      );

      return await getUserById(userId);
    } catch (e) {
      print('[DB ERROR] Failed to update user password hash: $e');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'user_password',
        resourceId: userId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Delete a user (may fail if foreign key constraints exist)
  Future<void> deleteUser(String userId) async {
    // Perform cascading cleanup to avoid foreign key constraint failures.
    try {
      _db.execute('BEGIN TRANSACTION');

      // 1) Delete media blobs for documents owned by the user
      final docIdsStmt =
          _db.prepare('SELECT id FROM documents WHERE owner_id = ?');
      final docRows = docIdsStmt.select([userId]);
      docIdsStmt.dispose();

      if (docRows.isNotEmpty) {
        final ids = docRows.map((r) => r.toMap()['id'] as String).toList();
        // Delete media blobs referencing these documents
        final placeholders = List.filled(ids.length, '?').join(',');
        final deleteMediaStmt = _db.prepare(
            'DELETE FROM media_blobs WHERE document_id IN ($placeholders)');
        deleteMediaStmt.execute(ids);
        deleteMediaStmt.dispose();
      }

      // 2) Delete documents owned by the user
      final delDocsStmt =
          _db.prepare('DELETE FROM documents WHERE owner_id = ?');
      delDocsStmt.execute([userId]);
      delDocsStmt.dispose();

      // 3) For collections owned by the user, delete their documents and media, then delete the collections
      final collStmt =
          _db.prepare('SELECT id FROM collections WHERE owner_id = ?');
      final collRows = collStmt.select([userId]);
      collStmt.dispose();

      for (final row in collRows) {
        final collId = row.toMap()['id'] as String;

        // Delete media blobs for documents in this collection
        final deleteMediaForColl = _db.prepare(
            r"DELETE FROM media_blobs WHERE document_id IN (SELECT id FROM documents WHERE collection_id = ?)");
        deleteMediaForColl.execute([collId]);
        deleteMediaForColl.dispose();

        // Delete documents in this collection
        final deleteDocsForColl =
            _db.prepare('DELETE FROM documents WHERE collection_id = ?');
        deleteDocsForColl.execute([collId]);
        deleteDocsForColl.dispose();

        // Delete the collection itself
        final deleteColl = _db.prepare('DELETE FROM collections WHERE id = ?');
        deleteColl.execute([collId]);
        deleteColl.dispose();
      }

      // 4) Delete audit log entries referencing this user (to avoid FK issues)
      final deleteLogs = _db.prepare('DELETE FROM audit_log WHERE user_id = ?');
      deleteLogs.execute([userId]);
      deleteLogs.dispose();

      // 5) Finally delete the user
      final stmt = _db.prepare('DELETE FROM users WHERE id = ?');
      stmt.execute([userId]);
      stmt.dispose();

      _db.execute('COMMIT');

      await _logDbAction(
        action: 'DELETE',
        resourceType: 'user',
        resourceId: userId,
        status: 'success',
      );
    } catch (e) {
      try {
        _db.execute('ROLLBACK');
      } catch (_) {}
      print('[DB ERROR] Failed to delete user: $e');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'user',
        resourceId: userId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // === COLLECTION OPERATIONS ===

  /// Create a new collection
  Future<Collection> createCollection(Collection collection) async {
    try {
      final rulesJson = _jsonEncode(collection.rules);
      final stmt =
          _db.prepare('INSERT INTO collections VALUES (?, ?, ?, ?, ?, ?)');
      stmt.execute([
        collection.id,
        collection.ownerId,
        collection.name,
        rulesJson,
        collection.createdAt.millisecondsSinceEpoch,
        collection.updatedAt.millisecondsSinceEpoch,
      ]);
      stmt.dispose();

      print('[DB] Collection created: ${collection.name}');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'collection',
        resourceId: collection.id,
        status: 'success',
      );
      return collection;
    } catch (e) {
      print('[DB ERROR] Failed to create collection: $e');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'collection',
        resourceId: collection.id,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Get collection by ID
  Future<Collection?> getCollection(String collectionId) async {
    try {
      final stmt = _db.prepare('SELECT * FROM collections WHERE id = ?');
      final rows = stmt.select([collectionId]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      final map = rows.first.toMap();
      map['rules'] = _jsonDecode(map['rules'] as String);
      return Collection.fromJson(map);
    } catch (e) {
      print('[DB ERROR] Failed to get collection: $e');
      rethrow;
    }
  }

  /// Get collection by name
  Future<Collection?> getCollectionByName(String name) async {
    try {
      final stmt = _db.prepare('SELECT * FROM collections WHERE name = ?');
      final rows = stmt.select([name]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      final map = rows.first.toMap();
      map['rules'] = _jsonDecode(map['rules'] as String);
      return Collection.fromJson(map);
    } catch (e) {
      print('[DB ERROR] Failed to get collection by name: $e');
      rethrow;
    }
  }

  /// Get collections for a user
  Future<List<Collection>> getUserCollections(String userId) async {
    try {
      final stmt = _db.prepare(
          'SELECT * FROM collections WHERE owner_id = ? ORDER BY created_at DESC');
      final rows = stmt.select([userId]);
      stmt.dispose();

      return rows.map((r) {
        final map = r.toMap();
        map['rules'] = _jsonDecode(map['rules'] as String);
        return Collection.fromJson(map);
      }).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get user collections: $e');
      rethrow;
    }
  }

  /// Get all collections (admin only)
  Future<List<Collection>> getAllCollections() async {
    try {
      final rows =
          _db.select('SELECT * FROM collections ORDER BY created_at DESC');
      return rows.map((r) {
        final map = r.toMap();
        map['rules'] = _jsonDecode(map['rules'] as String);
        return Collection.fromJson(map);
      }).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get all collections: $e');
      rethrow;
    }
  }

  /// Update collection rules
  Future<Collection?> updateCollectionRules(
      String collectionId, Map<String, dynamic> rules) async {
    try {
      final rulesJson = _jsonEncode(rules);
      final stmt = _db.prepare('''
        UPDATE collections
        SET rules = ?, updated_at = ?
        WHERE id = ?
      ''');
      stmt.execute([
        rulesJson,
        DateTime.now().millisecondsSinceEpoch,
        collectionId,
      ]);
      stmt.dispose();

      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'collection_rules',
        resourceId: collectionId,
        status: 'success',
      );

      return await getCollection(collectionId);
    } catch (e) {
      print('[DB ERROR] Failed to update collection rules: $e');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'collection_rules',
        resourceId: collectionId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Delete a collection and all its documents and media
  Future<void> deleteCollection(String collectionId) async {
    try {
      _db.execute('BEGIN TRANSACTION');

      // 1) Delete all media blobs for documents in this collection
      final deleteMediaStmt = _db.prepare(
          r'DELETE FROM media_blobs WHERE document_id IN (SELECT id FROM documents WHERE collection_id = ?)');
      deleteMediaStmt.execute([collectionId]);
      deleteMediaStmt.dispose();

      // 2) Delete all documents in this collection
      final deleteDocsStmt =
          _db.prepare('DELETE FROM documents WHERE collection_id = ?');
      deleteDocsStmt.execute([collectionId]);
      deleteDocsStmt.dispose();

      // 3) Delete the collection itself
      final deleteCollStmt =
          _db.prepare('DELETE FROM collections WHERE id = ?');
      deleteCollStmt.execute([collectionId]);
      deleteCollStmt.dispose();

      _db.execute('COMMIT');

      print('[DB] Collection deleted: $collectionId');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'collection',
        resourceId: collectionId,
        status: 'success',
      );
    } catch (e) {
      _db.execute('ROLLBACK');
      print('[DB ERROR] Failed to delete collection: $e');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'collection',
        resourceId: collectionId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // === DOCUMENT OPERATIONS ===

  /// Create a new document
  Future<Document> createDocument(Document document) async {
    try {
      final dataJson = _jsonEncode(document.data);
      final stmt =
          _db.prepare('INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?)');
      stmt.execute([
        document.id,
        document.collectionId,
        document.ownerId,
        dataJson,
        document.createdAt.millisecondsSinceEpoch,
        document.updatedAt.millisecondsSinceEpoch,
      ]);
      stmt.dispose();

      print('[DB] Document created: ${document.id}');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'document',
        resourceId: document.id,
        status: 'success',
      );
      return document;
    } catch (e) {
      print('[DB ERROR] Failed to create document: $e');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'document',
        resourceId: document.id,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Get document by ID
  Future<Document?> getDocument(String documentId) async {
    try {
      final stmt = _db.prepare('SELECT * FROM documents WHERE id = ?');
      final rows = stmt.select([documentId]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      final map = rows.first.toMap();
      map['data'] = _jsonDecode(map['data'] as String);
      return Document.fromJson(map);
    } catch (e) {
      print('[DB ERROR] Failed to get document: $e');
      rethrow;
    }
  }

  /// Get documents in a collection with pagination
  Future<List<Document>> getCollectionDocuments(
    String collectionId, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final stmt = _db.prepare('''
        SELECT * FROM documents 
        WHERE collection_id = ? 
        ORDER BY created_at DESC 
        LIMIT ? OFFSET ?
      ''');
      final rows = stmt.select([collectionId, limit, offset]);
      stmt.dispose();

      return rows.map((r) {
        final map = r.toMap();
        map['data'] = _jsonDecode(map['data'] as String);
        return Document.fromJson(map);
      }).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get collection documents: $e');
      rethrow;
    }
  }

  /// Update a document
  Future<Document> updateDocument(Document document) async {
    try {
      final dataJson = _jsonEncode(document.data);
      final stmt = _db.prepare('''
        UPDATE documents 
        SET data = ?, updated_at = ? 
        WHERE id = ?
      ''');
      stmt.execute([
        dataJson,
        document.updatedAt.millisecondsSinceEpoch,
        document.id,
      ]);
      stmt.dispose();

      print('[DB] Document updated: ${document.id}');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'document',
        resourceId: document.id,
        status: 'success',
      );
      return document;
    } catch (e) {
      print('[DB ERROR] Failed to update document: $e');
      await _logDbAction(
        action: 'UPDATE',
        resourceType: 'document',
        resourceId: document.id,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    try {
      // Also delete any media attached to this document
      final deleteMediaStmt =
          _db.prepare('DELETE FROM media_blobs WHERE document_id = ?');
      deleteMediaStmt.execute([documentId]);
      deleteMediaStmt.dispose();

      // Delete the document
      final deleteDocStmt = _db.prepare('DELETE FROM documents WHERE id = ?');
      deleteDocStmt.execute([documentId]);
      deleteDocStmt.dispose();

      print('[DB] Document deleted: $documentId');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'document',
        resourceId: documentId,
        status: 'success',
      );
    } catch (e) {
      print('[DB ERROR] Failed to delete document: $e');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'document',
        resourceId: documentId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // === ADVANCED QUERY OPERATIONS ===

  /// Execute admin SQL statements (read + write/destructive) with statement limit.
  ///
  /// Rules:
  /// - Maximum 5 statements per execution.
  /// - Bind parameters are supported only for single-statement execution.
  /// - For row-producing statements (SELECT/WITH/PRAGMA), result rows can be capped.
  Future<List<Map<String, Object?>>> executeAdminSql(
    String sql, {
    List<Object?> params = const [],
    int? maxRows,
    bool disableRowCap = false,
    String actorId = 'system',
    String source = 'admin_sql',
  }) async {
    final normalizedSql = sql.trim();
    if (normalizedSql.isEmpty) {
      throw ArgumentError('SQL cannot be empty.');
    }

    final statements = _splitSqlStatements(normalizedSql);
    if (statements.isEmpty) {
      throw ArgumentError('No valid SQL statement found.');
    }
    if (statements.length > 5) {
      throw ArgumentError(
          'Maximum 5 SQL statements are allowed per execution.');
    }
    if (statements.length > 1 && params.isNotEmpty) {
      throw ArgumentError(
        'Bind params are only supported for single-statement execution.',
      );
    }

    final results = <Map<String, Object?>>[];
    final effectiveMaxRows = disableRowCap ? null : (maxRows ?? 200);

    try {
      for (var i = 0; i < statements.length; i++) {
        final statement = statements[i];
        final keyword = _statementKeyword(statement);
        final isReadStatement =
            keyword == 'select' || keyword == 'with' || keyword == 'pragma';
        final statementId = '$source:${i + 1}';
        final trimmedStatement =
            statement.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (isReadStatement) {
          final stmt = _db.prepare(statement);
          final rows = stmt.select(i == 0 ? params : const []);
          stmt.dispose();

          final mappedRows = rows.map((r) => r.toMap()).toList();
          final cappedRows = effectiveMaxRows == null
              ? mappedRows
              : mappedRows.take(effectiveMaxRows).toList();

          results.add({
            'statement_index': i + 1,
            'statement_type': keyword,
            'rows': cappedRows,
            'row_count': cappedRows.length,
            'row_cap_applied': effectiveMaxRows != null,
          });

          await _logDbAction(
            action: 'QUERY',
            resourceType: 'sql_statement',
            resourceId: statementId,
            status: 'success',
            details:
                '$keyword rows=${cappedRows.length} cap=${effectiveMaxRows ?? 'off'} sql="$trimmedStatement"',
            actorId: actorId,
          );
          continue;
        }

        final stmt = _db.prepare(statement);
        stmt.execute(i == 0 ? params : const []);
        stmt.dispose();

        results.add({
          'statement_index': i + 1,
          'statement_type': keyword,
          'rows': const <Map<String, Object?>>[],
          'row_count': 0,
          'row_cap_applied': false,
        });

        await _logDbAction(
          action: 'QUERY',
          resourceType: 'sql_statement',
          resourceId: statementId,
          status: 'success',
          details: '$keyword sql="$trimmedStatement"',
          actorId: actorId,
        );
      }

      return results;
    } catch (e) {
      await _logDbAction(
        action: 'QUERY',
        resourceType: 'sql_statement',
        resourceId: source,
        status: 'failed',
        errorMessage: e.toString(),
        details: sql,
        actorId: actorId,
      );
      print('[DB ERROR] Failed to execute admin SQL: $e');
      rethrow;
    }
  }

  /// Split SQL into semicolon-delimited statements, respecting simple quoted strings.
  List<String> _splitSqlStatements(String sql) {
    final statements = <String>[];
    final buffer = StringBuffer();

    bool inSingleQuote = false;
    bool inDoubleQuote = false;

    for (var i = 0; i < sql.length; i++) {
      final ch = sql[i];

      if (ch == "'" && !inDoubleQuote) {
        final escaped = i > 0 && sql[i - 1] == '\\';
        if (!escaped) inSingleQuote = !inSingleQuote;
      } else if (ch == '"' && !inSingleQuote) {
        final escaped = i > 0 && sql[i - 1] == '\\';
        if (!escaped) inDoubleQuote = !inDoubleQuote;
      }

      if (ch == ';' && !inSingleQuote && !inDoubleQuote) {
        final statement = buffer.toString().trim();
        if (statement.isNotEmpty) {
          statements.add(statement);
        }
        buffer.clear();
        continue;
      }

      buffer.write(ch);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      statements.add(tail);
    }

    return statements;
  }

  String _statementKeyword(String statement) {
    final normalized = statement.trimLeft().toLowerCase();
    final firstToken = normalized.split(RegExp(r'\s+')).first;
    return firstToken;
  }

  // === MEDIA OPERATIONS ===

  /// Store media blob
  Future<MediaBlob> createMediaBlob(MediaBlob media) async {
    try {
      final stmt = _db.prepare('''
        INSERT INTO media_blobs 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        media.id,
        media.documentId,
        media.fileName,
        media.mimeType,
        media.originalSize,
        media.compressedSize,
        media.compressionAlgo,
        media.blobData,
        media.createdAt.millisecondsSinceEpoch,
      ]);
      stmt.dispose();

      print('[DB] Media blob created: ${media.id}');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'media_blob',
        resourceId: media.id,
        status: 'success',
      );
      return media;
    } catch (e) {
      print('[DB ERROR] Failed to create media blob: $e');
      await _logDbAction(
        action: 'CREATE',
        resourceType: 'media_blob',
        resourceId: media.id,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Get media blob by ID
  Future<MediaBlob?> getMediaBlob(String mediaId) async {
    try {
      final stmt = _db.prepare('SELECT * FROM media_blobs WHERE id = ?');
      final rows = stmt.select([mediaId]);
      stmt.dispose();

      if (rows.isEmpty) return null;

      return MediaBlob.fromJson(rows.first.toMap());
    } catch (e) {
      print('[DB ERROR] Failed to get media blob: $e');
      rethrow;
    }
  }

  /// Get all media blobs for a document
  Future<List<MediaBlob>> getMediaBlobsByDocument(String documentId) async {
    try {
      final stmt =
          _db.prepare('SELECT * FROM media_blobs WHERE document_id = ?');
      final rows = stmt.select([documentId]);
      stmt.dispose();

      return rows.map((r) => MediaBlob.fromJson(r.toMap())).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get media blobs for document: $e');
      rethrow;
    }
  }

  /// Delete a media blob
  Future<void> deleteMediaBlob(String mediaId) async {
    try {
      final stmt = _db.prepare('DELETE FROM media_blobs WHERE id = ?');
      stmt.execute([mediaId]);
      stmt.dispose();

      print('[DB] Media blob deleted: $mediaId');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'media_blob',
        resourceId: mediaId,
        status: 'success',
      );
    } catch (e) {
      print('[DB ERROR] Failed to delete media blob: $e');
      await _logDbAction(
        action: 'DELETE',
        resourceType: 'media_blob',
        resourceId: mediaId,
        status: 'failed',
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  // === AUDIT LOG OPERATIONS ===

  /// Log an action to audit trail
  Future<AuditLog> logAction(AuditLog entry) async {
    try {
      final stmt = _db.prepare('''
        INSERT INTO audit_log (
          id,
          user_id,
          action,
          resource_type,
          resource_id,
          status,
          error_message,
          details,
          timestamp
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        entry.id,
        entry.userId,
        entry.action,
        entry.resourceType,
        entry.resourceId,
        entry.status,
        entry.errorMessage,
        entry.details,
        entry.timestamp.millisecondsSinceEpoch,
      ]);
      stmt.dispose();

      return entry;
    } catch (e) {
      print('[DB ERROR] Failed to log action: $e');
      rethrow;
    }
  }

  /// Get recent audit log entries
  Future<List<AuditLog>> getAuditLog({int limit = 100}) async {
    try {
      final stmt = _db.prepare('''
        SELECT * FROM audit_log 
        ORDER BY timestamp DESC 
        LIMIT ?
      ''');
      final rows = stmt.select([limit]);
      stmt.dispose();

      return rows.map((r) => AuditLog.fromJson(r.toMap())).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get audit log: $e');
      rethrow;
    }
  }

  /// Get audit log for specific user
  Future<List<AuditLog>> getUserAuditLog(String userId,
      {int limit = 100}) async {
    try {
      final stmt = _db.prepare('''
        SELECT * FROM audit_log 
        WHERE user_id = ? 
        ORDER BY timestamp DESC 
        LIMIT ?
      ''');
      final rows = stmt.select([userId, limit]);
      stmt.dispose();

      return rows.map((r) => AuditLog.fromJson(r.toMap())).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get user audit log: $e');
      rethrow;
    }
  }

  // === HELPER METHODS ===

  /// Execute a raw SQL query (admin only)
  List<Map<String, dynamic>> executeRawQuery(String sql,
      [List<dynamic>? params]) {
    try {
      final stmt = _db.prepare(sql);
      final result = params == null ? stmt.select() : stmt.select(params);
      stmt.dispose();

      return result.map((r) => r.toMap()).toList();
    } catch (e) {
      print('[DB ERROR] Failed to execute raw query: $e');
      rethrow;
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final userCount = _db.select('SELECT COUNT(*) as count FROM users');
      final collectionCount =
          _db.select('SELECT COUNT(*) as count FROM collections');
      final documentCount =
          _db.select('SELECT COUNT(*) as count FROM documents');
      final mediaCount =
          _db.select('SELECT COUNT(*) as count FROM media_blobs');

      final users = userCount.first.toMap()['count'];
      final collections = collectionCount.first.toMap()['count'];
      final documents = documentCount.first.toMap()['count'];
      final mediaBlobs = mediaCount.first.toMap()['count'];

      return {
        'users': users,
        'collections': collections,
        'documents': documents,
        'media_blobs': mediaBlobs,
        'user_count': users,
        'collection_count': collections,
        'document_count': documents,
        'media_blob_count': mediaBlobs,
      };
    } catch (e) {
      print('[DB ERROR] Failed to get database stats: $e');
      rethrow;
    }
  }

  // === JSON UTILITY METHODS ===

  /// Encode map to JSON string
  String _jsonEncode(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  /// Decode JSON string to map
  Map<String, dynamic> _jsonDecode(String json) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      print('[DB ERROR] JSON decode error: $e');
      return {};
    }
  }

  Future<void> _logDbAction({
    required String action,
    required String resourceType,
    required String resourceId,
    required String status,
    String? errorMessage,
    String? details,
    String? actorId,
  }) async {
    final entry = AuditLog(
      userId: actorId ?? _auditActor,
      action: action,
      resourceType: resourceType,
      resourceId: resourceId,
      status: status,
      errorMessage: errorMessage,
      details: details,
    );

    try {
      await logAction(entry);
    } catch (_) {
      // Never allow audit persistence failures to break DB operations.
    }

    try {
      await logger.logAction(entry);
    } catch (_) {
      // Never allow logging failures to break DB operations.
    }
  }
}

/// Global database instance
late DatabaseManager database;
