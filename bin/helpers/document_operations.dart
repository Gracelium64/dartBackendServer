// bin/helpers/document_operations.dart
// Helper functions for document and collection CRUD operations

import 'dart:convert';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/database/models.dart';
import 'terminal_ui.dart';
import 'formatting.dart';

/// List all collections
Future<void> listCollections(DatabaseManager database) async {
  final collections = await database.getAllCollections();

  if (collections.isEmpty) {
    TerminalUI.printWarning('No collections found');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'collection',
      resourceId: 'all',
      status: 'success',
    ));
    return;
  }

  final rows = collections.map((c) {
    return [
      c.id,
      c.name,
      c.ownerId,
      c.createdAt.toString().substring(0, 19),
    ];
  }).toList();

  TerminalUI.printTable(
    ['ID', 'Name', 'Owner ID', 'Created'],
    rows,
  );
  TerminalUI.printSuccess('Total collections: ${collections.length}');
  await database.logAction(AuditLog(
    userId: 'admin_console',
    action: 'LIST',
    resourceType: 'collection',
    resourceId: 'all',
    status: 'success',
  ));
}

/// Create a new collection
Future<void> createCollection(DatabaseManager database) async {
  TerminalUI.printHeader('Create Collection');

  final ownerInput =
      TerminalUI.prompt('Owner (User ID or Email)', required: true);
  final name = TerminalUI.prompt('Collection Name', required: true);

  // Resolve owner
  var owner = await database.getUserById(ownerInput);
  owner ??= await database.getUserByEmail(ownerInput);

  if (owner == null) {
    TerminalUI.printError('Owner not found');
    return;
  }

  try {
    final collection = Collection(
      ownerId: owner.id,
      name: name,
      rules: {},
    );
    await database.createCollection(collection);
    TerminalUI.printSuccess('Collection created: $name');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'collection',
      resourceId: collection.id,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'collection',
      resourceId: 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to create collection: $e');
  }
}

/// Delete a collection and all contained documents/media
Future<void> deleteCollection(DatabaseManager database) async {
  TerminalUI.printHeader('Delete Collection');

  final collectionId = TerminalUI.prompt('Collection ID', required: true);

  if (!TerminalUI.confirm(
      'Delete collection $collectionId and all its documents/media?')) {
    TerminalUI.printWarning('Cancelled');
    return;
  }

  try {
    final existing = await database.getCollection(collectionId);
    if (existing == null) {
      TerminalUI.printError('Collection not found');
      await database.logAction(AuditLog(
        userId: 'admin_console',
        action: 'DELETE',
        resourceType: 'collection',
        resourceId: collectionId,
        status: 'failed',
        errorMessage: 'Collection not found',
      ));
      return;
    }

    await database.deleteCollection(collectionId);
    TerminalUI.printSuccess('Collection deleted');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'collection',
      resourceId: collectionId,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'collection',
      resourceId: collectionId,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to delete collection: $e');
  }
}

/// Create a new document in a collection
Future<void> createDocument(DatabaseManager database) async {
  TerminalUI.printHeader('Create Document');

  final collectionId = TerminalUI.prompt('Collection ID', required: true);
  final ownerInput =
      TerminalUI.prompt('Owner (User ID or Email)', required: true);

  // Verify collection exists
  final collection = await database.getCollection(collectionId);
  if (collection == null) {
    TerminalUI.printError('Collection not found');
    return;
  }

  // Resolve owner
  var owner = await database.getUserById(ownerInput);
  owner ??= await database.getUserByEmail(ownerInput);

  if (owner == null) {
    TerminalUI.printError('Owner not found');
    return;
  }

  print('\nEnter document data as JSON:');
  print('Example: {"title": "My Document", "content": "Hello"}');
  final jsonInput = TerminalUI.prompt('JSON data', required: true);

  try {
    final data = jsonDecode(jsonInput) as Map<String, dynamic>;

    final doc = Document(
      collectionId: collectionId,
      ownerId: owner.id,
      data: data,
    );

    final created = await database.createDocument(doc);
    TerminalUI.printSuccess('Document created with ID: ${created.id}');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'document',
      resourceId: created.id,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'document',
      resourceId: 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to create document: $e');
  }
}

/// Read/display a document
Future<void> readDocument(DatabaseManager database) async {
  TerminalUI.printHeader('Read Document');

  final docId = TerminalUI.prompt('Document ID', required: true);

  try {
    final doc = await database.getDocument(docId);
    if (doc == null) {
      TerminalUI.printError('Document not found');
      await database.logAction(AuditLog(
        userId: 'admin_console',
        action: 'READ',
        resourceType: 'document',
        resourceId: docId,
        status: 'failed',
        errorMessage: 'Document not found',
      ));
      return;
    }

    print('\n${'=' * 70}');
    print('ID:           ${doc.id}');
    print('Collection:   ${doc.collectionId}');
    print('Owner:        ${doc.ownerId}');
    print('Created:      ${doc.createdAt}');
    print('Updated:      ${doc.updatedAt}');
    print('Data:');
    print(JsonEncoder.withIndent('  ').convert(doc.data));
    print('=' * 70);
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'READ',
      resourceType: 'document',
      resourceId: doc.id,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'READ',
      resourceType: 'document',
      resourceId: docId,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to read document: $e');
  }
}

/// Update a document
Future<void> updateDocument(DatabaseManager database) async {
  TerminalUI.printHeader('Update Document');

  final docId = TerminalUI.prompt('Document ID', required: true);

  try {
    final doc = await database.getDocument(docId);
    if (doc == null) {
      TerminalUI.printError('Document not found');
      return;
    }

    print('\nCurrent data:');
    print(JsonEncoder.withIndent('  ').convert(doc.data));

    print('\nEnter new data as JSON:');
    final jsonInput = TerminalUI.prompt('JSON data', required: true);

    final newData = jsonDecode(jsonInput) as Map<String, dynamic>;
    final updatedDoc = Document(
      id: doc.id,
      collectionId: doc.collectionId,
      ownerId: doc.ownerId,
      data: newData,
      createdAt: doc.createdAt,
    );

    await database.updateDocument(updatedDoc);
    TerminalUI.printSuccess('Document updated');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'document',
      resourceId: docId,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'document',
      resourceId: docId,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to update document: $e');
  }
}

/// Delete a document
Future<void> deleteDocument(DatabaseManager database) async {
  TerminalUI.printHeader('Delete Document');

  final docId = TerminalUI.prompt('Document ID', required: true);

  if (!TerminalUI.confirm('Delete document $docId?')) {
    TerminalUI.printWarning('Cancelled');
    return;
  }

  try {
    await database.deleteDocument(docId);
    TerminalUI.printSuccess('Document deleted');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'document',
      resourceId: docId,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'document',
      resourceId: docId,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to delete document: $e');
  }
}

/// List documents in a collection
Future<void> listDocuments(DatabaseManager database) async {
  TerminalUI.printHeader('List Documents');

  final collectionId = TerminalUI.prompt('Collection ID', required: true);
  final limitStr = TerminalUI.prompt('Limit (default 50)', required: false);
  final limit = int.tryParse(limitStr) ?? 50;

  try {
    final docs = await database.getCollectionDocuments(
      collectionId,
      limit: limit,
      offset: 0,
    );

    if (docs.isEmpty) {
      TerminalUI.printWarning('No documents found');
      await database.logAction(AuditLog(
        userId: 'admin_console',
        action: 'LIST',
        resourceType: 'document',
        resourceId: collectionId,
        status: 'success',
      ));
      return;
    }

    final rows = docs.map((doc) {
      final dataPreview = truncate(jsonEncode(doc.data), 50);
      return [
        doc.id,
        doc.ownerId,
        dataPreview,
        doc.updatedAt.toString().substring(0, 19),
      ];
    }).toList();

    TerminalUI.printTable(
      ['ID', 'Owner', 'Data Preview', 'Updated'],
      rows,
    );
    TerminalUI.printSuccess('Found ${docs.length} documents');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'document',
      resourceId: collectionId,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'document',
      resourceId: collectionId,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to list documents: $e');
  }
}
