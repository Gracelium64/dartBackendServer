// lib/database/models.dart
// Data models for SQLite schema
// Explanation for Flutter Developers:
// These are similar to model classes in your Flutter app (e.g., User, Post classes).
// They represent rows in database tables. The toJson() and fromJson() methods
// are like the serialization you do with json_serializable in Flutter.

import 'package:uuid/uuid.dart';

/// User model - represents a user account
class User {
  final String id;
  final String email;
  final String passwordHash;
  final String role; // 'admin' or 'user'
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    String? id,
    required this.email,
    required this.passwordHash,
    this.role = 'user',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert User to JSON (for database storage)
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'password_hash': passwordHash,
        'role': role,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  /// Create User from JSON (from database)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String,
      role: json['role'] as String? ?? 'user',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int? ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int? ?? 0),
    );
  }
}

/// Collection model - represents a collection of documents
/// Similar to a table in SQL or a subcollection in Firestore
class Collection {
  final String id;
  final String ownerId;
  final String name;
  final Map<String, dynamic>
      rules; // { read: [], write: [], public_read: false }
  final DateTime createdAt;
  final DateTime updatedAt;

  Collection({
    String? id,
    required this.ownerId,
    required this.name,
    Map<String, dynamic>? rules,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        rules = rules ??
            {
              'read': ['owner'],
              'write': ['owner'],
              'public_read': false,
            },
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'rules': rules,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      rules: json['rules'] as Map<String, dynamic>? ??
          {
            'read': ['owner'],
            'write': ['owner'],
            'public_read': false,
          },
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int? ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int? ?? 0),
    );
  }
}

/// Document model - represents a JSON document in a collection
class Document {
  final String id;
  final String collectionId;
  final String ownerId;
  final Map<String, dynamic> data; // The actual JSON data
  final DateTime createdAt;
  final DateTime updatedAt;

  Document({
    String? id,
    required this.collectionId,
    required this.ownerId,
    required this.data,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'collection_id': collectionId,
        'owner_id': ownerId,
        'data': data,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      collectionId: json['collection_id'] as String,
      ownerId: json['owner_id'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int? ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int? ?? 0),
    );
  }
}

/// MediaBlob model - represents compressed media data
class MediaBlob {
  final String id;
  final String documentId;
  final String fileName;
  final String mimeType;
  final int originalSize;
  final int compressedSize;
  final String compressionAlgo; // 'gzip', 'brotli', etc.
  final List<int> blobData; // The actual binary data
  final DateTime createdAt;

  MediaBlob({
    String? id,
    required this.documentId,
    required this.fileName,
    required this.mimeType,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionAlgo,
    required this.blobData,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'document_id': documentId,
        'file_name': fileName,
        'mime_type': mimeType,
        'original_size': originalSize,
        'compressed_size': compressedSize,
        'compression_algo': compressionAlgo,
        'blob_data': blobData,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MediaBlob.fromJson(Map<String, dynamic> json) {
    // SQLite returns blob data as Uint8List, convert to List<int>
    final blobDataRaw = json['blob_data'];
    final List<int> blobDataList;
    if (blobDataRaw is List<int>) {
      blobDataList = blobDataRaw;
    } else if (blobDataRaw is String) {
      // If it's a string (shouldn't happen but let's be safe)
      blobDataList = blobDataRaw.codeUnits;
    } else {
      // Treat as iterable and convert to list
      blobDataList = List<int>.from(blobDataRaw as Iterable);
    }

    return MediaBlob(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      originalSize: json['original_size'] as int,
      compressedSize: json['compressed_size'] as int,
      compressionAlgo: json['compression_algo'] as String,
      blobData: blobDataList,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int? ?? 0),
    );
  }
}

/// AuditLog model - represents an action taken in the database
/// Used for logging security events and for the live log display
class AuditLog {
  final String id;
  final String userId;
  final String action; // 'CREATE', 'READ', 'UPDATE', 'DELETE', 'LOGIN', etc.
  final String resourceType; // 'document', 'user', 'collection', etc.
  final String resourceId;
  final String status; // 'success', 'failed'
  final String? errorMessage;
  final String?
      details; // Exact CRUD command/parameters e.g. "CREATE user john admin" or "UPDATE document {id: doc123, ...}"
  final DateTime timestamp;

  AuditLog({
    String? id,
    required this.userId,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.status,
    this.errorMessage,
    this.details,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'status': status,
        'error_message': errorMessage,
        'details': details,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      details: json['details'] as String?,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
    );
  }

  /// Format for log display (tab-separated)
  String toLogFormat() {
    return '${timestamp.toIso8601String()} | $userId | $action | $resourceType:$resourceId | $status | ${errorMessage ?? '-'} | ${details ?? '-'}';
  }
}
