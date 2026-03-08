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
import '../config.dart';
import '../logging/logger.dart';

extension RowToMap on Row {
  Map<String, Object?> toMap() {
    return Map<String, Object?>.from(this);
  }
}

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

  /// Singleton pattern - ensure only one database connection
  factory DatabaseManager() {
    _instance ??= DatabaseManager._internal();
    return _instance!;
  }

  DatabaseManager._internal();

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

    print('[DB] Database initialized successfully');
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
      final rows = _db.select('SELECT * FROM users');
      return rows.map((r) => User.fromJson(r.toMap())).toList();
    } catch (e) {
      print('[DB ERROR] Failed to get all users: $e');
      rethrow;
    }
  }

  /// Update a user's role
  Future<User?> updateUserRole(String userId, String role) async {
    try {
      final stmt = _db.prepare('''
        UPDATE users
        SET role = ?, updated_at = ?
        WHERE id = ?
      ''');
      stmt.execute([
        role,
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

  /// Delete a user (may fail if foreign key constraints exist)
  Future<void> deleteUser(String userId) async {
    try {
      final stmt = _db.prepare('DELETE FROM users WHERE id = ?');
      stmt.execute([userId]);
      stmt.dispose();

      await _logDbAction(
        action: 'DELETE',
        resourceType: 'user',
        resourceId: userId,
        status: 'success',
      );
    } catch (e) {
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
      }

      return results;
    } catch (e) {
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
        INSERT INTO audit_log 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      stmt.execute([
        entry.id,
        entry.userId,
        entry.action,
        entry.resourceType,
        entry.resourceId,
        entry.status,
        entry.errorMessage,
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

      return {
        'users': userCount.first.toMap()['count'],
        'collections': collectionCount.first.toMap()['count'],
        'documents': documentCount.first.toMap()['count'],
        'media_blobs': mediaCount.first.toMap()['count'],
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
  }) async {
    try {
      await logger.logAction(
        AuditLog(
          userId: 'system',
          action: action,
          resourceType: resourceType,
          resourceId: resourceId,
          status: status,
          errorMessage: errorMessage,
        ),
      );
    } catch (_) {
      // Never allow logging failures to break DB operations.
    }
  }
}

/// Global database instance
late DatabaseManager database;
