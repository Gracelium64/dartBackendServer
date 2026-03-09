// lib/database/migrations.dart
// Database schema initialization and migrations
// Explanation for Flutter Developers:
// This is like the schema definition in SQLite for Flutter apps.
// We create tables (similar to how you define data models) and indexes
// for efficient querying.

import 'package:sqlite3/sqlite3.dart';

/// Schema migration manager
/// Handles creating tables and running migrations
class SchemaMigration {
  /// Create all required database tables
  static void createTables(Database db) {
    print('[DB] Creating tables...');

    // Create Users table
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT DEFAULT 'user',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    print('  ✓ Created users table');

    // Create Collections table
    db.execute('''
      CREATE TABLE IF NOT EXISTS collections (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        rules TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (owner_id) REFERENCES users(id)
      )
    ''');
    print('  ✓ Created collections table');

    // Create Documents table
    db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        collection_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (collection_id) REFERENCES collections(id),
        FOREIGN KEY (owner_id) REFERENCES users(id)
      )
    ''');
    print('  ✓ Created documents table');

    // Create MediaBlobs table
    db.execute('''
      CREATE TABLE IF NOT EXISTS media_blobs (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        original_size INTEGER NOT NULL,
        compressed_size INTEGER NOT NULL,
        compression_algo TEXT NOT NULL,
        blob_data BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents(id)
      )
    ''');
    print('  ✓ Created media_blobs table');

    // Create AuditLog table
    db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        resource_type TEXT NOT NULL,
        resource_id TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        details TEXT,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    print('  ✓ Created audit_log table');

    // Create indexes for performance
    _createIndexes(db);

    print('[DB] Schema initialization complete');
  }

  /// Create indexes for frequently queried columns
  static void _createIndexes(Database db) {
    print('[DB] Creating indexes...');

    // Index for users by email (login queries)
    db.execute('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');

    // Index for documents by collection (listing queries)
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_documents_collection ON documents(collection_id)');

    // Index for documents by owner (user's documents)
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_documents_owner ON documents(owner_id)');

    // Index for collections by owner
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_collections_owner ON collections(owner_id)');

    // Index for media by document
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_media_document ON media_blobs(document_id)');

    // Index for audit log by timestamp (log retrieval)
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp)');

    // Index for audit log by user (finding user actions)
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id)');

    print('  ✓ Indexes created');
  }

  /// Run any pending migrations
  /// This is called on server startup to apply schema changes
  static void runMigrations(Database db) {
    print('[DB] Checking for pending migrations...');

    // Add audit details column for richer security/event context.
    try {
      db.execute('ALTER TABLE audit_log ADD COLUMN details TEXT');
      print('  ✓ Migration: Added details to audit_log');
    } catch (_) {
      // Column already exists, that's fine.
    }

    print('[DB] All migrations completed');
  }
}
