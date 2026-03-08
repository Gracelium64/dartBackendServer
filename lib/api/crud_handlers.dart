// lib/api/crud_handlers.dart
// CRUD operation handlers (Create, Read, Update, Delete)
// Explanation for Flutter Developers:
// These are the actual endpoint implementations that process requests.
// Each operation checks permissions, validates data, performs the DB operation,
// logs the action, and returns a response.

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import '../database/models.dart';
import '../database/db_manager.dart';
import '../auth/auth_service.dart';
import '../auth/rule_engine.dart';

/// Extract user info from JWT token in request
Future<Map<String, dynamic>?> _getUserFromRequest(Request request) async {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  final token = authHeader.substring(7); // Remove 'Bearer '
  final claims = AuthService.validateToken(token);
  return claims;
}

/// Create a new document in a collection
Response _jsonErrorResponse(int statusCode, String message) {
  return Response(
    statusCode,
    body: jsonEncode({'error': message}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Response> handleCreateDocument(Request request) async {
  try {
    final collectionId = request.params['collectionId'];
    if (collectionId == null) {
      return _jsonErrorResponse(400, 'Collection ID required');
    }

    // Check authentication
    final userClaims = await _getUserFromRequest(request);
    if (userClaims == null) {
      return _jsonErrorResponse(401, 'Not authenticated');
    }

    final userId = userClaims['sub'] as String;
    final user = await database.getUserById(userId);
    if (user == null) {
      return _jsonErrorResponse(403, 'User not found');
    }

    // Get collection and check write permission
    final collection = await database.getCollection(collectionId);
    if (collection == null) {
      return _jsonErrorResponse(404, 'Collection not found');
    }

    if (!RuleEngine.canWrite(userId, user.role, collection)) {
      // Log failed write attempt
      await database.logAction(AuditLog(
        userId: userId,
        action: 'CREATE',
        resourceType: 'document',
        resourceId: collectionId,
        status: 'failed',
        errorMessage: 'Permission denied',
      ));
      return _jsonErrorResponse(403, 'Permission denied');
    }

    // Parse request body
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Create document
    final newDoc = Document(
      collectionId: collectionId,
      ownerId: userId,
      data: data,
    );

    final createdDoc = await database.createDocument(newDoc);

    // Log successful creation
    await database.logAction(AuditLog(
      userId: userId,
      action: 'CREATE',
      resourceType: 'document',
      resourceId: createdDoc.id,
      status: 'success',
    ));

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {
          'id': createdDoc.id,
          'collection_id': createdDoc.collectionId,
          'data': createdDoc.data,
          'created_at': createdDoc.createdAt.toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[HANDLER ERROR] Create document failed: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }
}

/// Read a document from a collection
Future<Response> handleReadDocument(Request request) async {
  try {
    final collectionId = request.params['collectionId'];
    final docId = request.params['docId'];

    if (collectionId == null || docId == null) {
      return _jsonErrorResponse(400, 'Collection and document IDs required');
    }

    // Check authentication
    final userClaims = await _getUserFromRequest(request);
    if (userClaims == null) {
      return _jsonErrorResponse(401, 'Not authenticated');
    }

    final userId = userClaims['sub'] as String;
    final user = await database.getUserById(userId);
    if (user == null) {
      return _jsonErrorResponse(403, 'User not found');
    }

    // Get collection and check read permission
    final collection = await database.getCollection(collectionId);
    if (collection == null) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'READ',
        resourceType: 'collection',
        resourceId: collectionId,
        status: 'failed',
        errorMessage: 'Collection not found',
      ));
      return _jsonErrorResponse(404, 'Collection not found');
    }

    if (!RuleEngine.canRead(userId, user.role, collection)) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'READ',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Permission denied',
      ));
      return _jsonErrorResponse(403, 'Permission denied');
    }

    // Get document
    final doc = await database.getDocument(docId);
    if (doc == null) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'READ',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not found',
      ));
      return _jsonErrorResponse(404, 'Document not found');
    }

    // Verify document belongs to collection
    if (doc.collectionId != collectionId) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'READ',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not in collection',
      ));
      return _jsonErrorResponse(403, 'Document not in collection');
    }

    // Log successful read
    await database.logAction(AuditLog(
      userId: userId,
      action: 'READ',
      resourceType: 'document',
      resourceId: docId,
      status: 'success',
    ));

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {
          'id': doc.id,
          'collection_id': doc.collectionId,
          'data': doc.data,
          'created_at': doc.createdAt.toIso8601String(),
          'updated_at': doc.updatedAt.toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[HANDLER ERROR] Read document failed: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }
}

/// Update a document
Future<Response> handleUpdateDocument(Request request) async {
  try {
    final collectionId = request.params['collectionId'];
    final docId = request.params['docId'];

    if (collectionId == null || docId == null) {
      return _jsonErrorResponse(400, 'Collection and document IDs required');
    }

    // Check authentication
    final userClaims = await _getUserFromRequest(request);
    if (userClaims == null) {
      return _jsonErrorResponse(401, 'Not authenticated');
    }

    final userId = userClaims['sub'] as String;
    final user = await database.getUserById(userId);
    if (user == null) {
      return _jsonErrorResponse(403, 'User not found');
    }

    // Get collection and check write permission
    final collection = await database.getCollection(collectionId);
    if (collection == null) {
      return _jsonErrorResponse(404, 'Collection not found');
    }

    if (!RuleEngine.canWrite(userId, user.role, collection)) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'UPDATE',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Permission denied',
      ));
      return _jsonErrorResponse(403, 'Permission denied');
    }

    // Get existing document
    final existingDoc = await database.getDocument(docId);
    if (existingDoc == null) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'UPDATE',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not found',
      ));
      return _jsonErrorResponse(404, 'Document not found');
    }

    if (existingDoc.collectionId != collectionId) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'UPDATE',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not in collection',
      ));
      return _jsonErrorResponse(403, 'Document not in collection');
    }

    // Parse update data
    final body = await request.readAsString();
    final updateData = jsonDecode(body) as Map<String, dynamic>;

    // Check merge flag from query params
    final merge = (request.url.queryParameters['merge'] ?? 'true') == 'true';

    // Merge or replace data
    final newData = merge ? {...existingDoc.data, ...updateData} : updateData;

    // Update document
    final updatedDoc = await database.updateDocument(Document(
      id: existingDoc.id,
      collectionId: collectionId,
      ownerId: existingDoc.ownerId,
      data: newData,
      createdAt: existingDoc.createdAt,
      updatedAt: DateTime.now(),
    ));

    // Log successful update
    await database.logAction(AuditLog(
      userId: userId,
      action: 'UPDATE',
      resourceType: 'document',
      resourceId: docId,
      status: 'success',
    ));

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {
          'id': updatedDoc.id,
          'collection_id': updatedDoc.collectionId,
          'data': updatedDoc.data,
          'created_at': updatedDoc.createdAt.toIso8601String(),
          'updated_at': updatedDoc.updatedAt.toIso8601String(),
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[HANDLER ERROR] Update document failed: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }
}

/// Delete a document
Future<Response> handleDeleteDocument(Request request) async {
  try {
    final collectionId = request.params['collectionId'];
    final docId = request.params['docId'];

    if (collectionId == null || docId == null) {
      return _jsonErrorResponse(400, 'Collection and document IDs required');
    }

    // Check authentication
    final userClaims = await _getUserFromRequest(request);
    if (userClaims == null) {
      return _jsonErrorResponse(401, 'Not authenticated');
    }

    final userId = userClaims['sub'] as String;
    final user = await database.getUserById(userId);
    if (user == null) {
      return _jsonErrorResponse(403, 'User not found');
    }

    // Get collection and check write permission
    final collection = await database.getCollection(collectionId);
    if (collection == null) {
      return _jsonErrorResponse(404, 'Collection not found');
    }

    if (!RuleEngine.canWrite(userId, user.role, collection)) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'DELETE',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Permission denied',
      ));
      return _jsonErrorResponse(403, 'Permission denied');
    }

    // Get document to verify it exists and belongs to collection
    final doc = await database.getDocument(docId);
    if (doc == null || doc.collectionId != collectionId) {
      await database.logAction(AuditLog(
        userId: userId,
        action: 'DELETE',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not found',
      ));
      return _jsonErrorResponse(404, 'Document not found');
    }

    // Delete document
    await database.deleteDocument(docId);

    // Log successful deletion
    await database.logAction(AuditLog(
      userId: userId,
      action: 'DELETE',
      resourceType: 'document',
      resourceId: docId,
      status: 'success',
    ));

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': {'deleted': true},
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[HANDLER ERROR] Delete document failed: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }
}

/// List documents in a collection
Future<Response> handleListDocuments(Request request) async {
  try {
    final collectionId = request.params['collectionId'];
    if (collectionId == null) {
      return _jsonErrorResponse(400, 'Collection ID required');
    }

    // Check authentication
    final userClaims = await _getUserFromRequest(request);
    if (userClaims == null) {
      return _jsonErrorResponse(401, 'Not authenticated');
    }

    final userId = userClaims['sub'] as String;
    final user = await database.getUserById(userId);
    if (user == null) {
      return _jsonErrorResponse(403, 'User not found');
    }

    // Get collection and check read permission
    final collection = await database.getCollection(collectionId);
    if (collection == null) {
      return _jsonErrorResponse(404, 'Collection not found');
    }

    if (!RuleEngine.canRead(userId, user.role, collection)) {
      return _jsonErrorResponse(403, 'Permission denied');
    }

    // Parse pagination parameters
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;

    // Get documents
    final docs = await database.getCollectionDocuments(collectionId,
        limit: limit, offset: offset);

    return Response.ok(
      jsonEncode({
        'success': true,
        'data': docs
            .map((d) => {
                  'id': d.id,
                  'collection_id': d.collectionId,
                  'data': d.data,
                  'created_at': d.createdAt.toIso8601String(),
                  'updated_at': d.updatedAt.toIso8601String(),
                })
            .toList(),
        'pagination': {
          'limit': limit,
          'offset': offset,
          'count': docs.length,
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[HANDLER ERROR] List documents failed: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
    );
  }
}
