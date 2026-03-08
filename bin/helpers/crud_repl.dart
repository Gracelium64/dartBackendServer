// bin/helpers/crud_repl.dart
// Raw CRUD command interface for admin console
// Allows executing database commands in a SQL-like syntax

import 'dart:io';
import 'dart:convert';
import '../../lib/database/db_manager.dart';
import '../../lib/database/models.dart';
import '../../lib/logging/logger.dart';

/// Raw CRUD REPL - Read-Eval-Print Loop for direct database commands
Future<void> startCrudRepl(DatabaseManager database) async {
  print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║                    Raw CRUD Command Interface                                   ║
║                                                                                  ║
║  Syntax Examples:                                                               ║
║    CREATE USER <email> <password> [<role>]                                     ║
║    LIST USERS                                                                   ║
║    DELETE USER <userId>                                                        ║
║    CREATE COLLECTION <ownerId> <collectionName>                                ║
║    CREATE DOCUMENT <collectionId> <userId> <jsonData>                          ║
║    READ DOCUMENT <documentId>                                                  ║
║    UPDATE DOCUMENT <documentId> <jsonData>                                     ║
║    DELETE DOCUMENT <documentId>                                                ║
║    LIST DOCUMENTS <collectionId>                                               ║
║    LIST COLLECTIONS                                                             ║
║    UPDATE RULES <collectionId> <jsonRules>                                     ║
║                                                                                  ║
║  Type 'help' for more commands or 'exit' to quit                               ║
╚════════════════════════════════════════════════════════════════════════════════╝
''');

  bool running = true;
  while (running) {
    stdout.write('\ncrud> ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) continue;

    final parts = input.split(RegExp(r'\s+'));
    final command = parts[0].toUpperCase();

    try {
      switch (command) {
        case 'EXIT':
        case 'QUIT':
          running = false;
          print('Exiting CRUD interface...');
          break;

        case 'HELP':
          _printHelp();
          break;

        case 'CREATE':
          await _handleCreate(parts.skip(1).toList(), database, input);
          break;

        case 'READ':
          await _handleRead(parts.skip(1).toList(), database, input);
          break;

        case 'UPDATE':
          await _handleUpdate(parts.skip(1).toList(), database, input);
          break;

        case 'DELETE':
          await _handleDelete(parts.skip(1).toList(), database, input);
          break;

        case 'LIST':
          await _handleList(parts.skip(1).toList(), database, input);
          break;

        default:
          print('❌ Unknown command: $command');
          print('   Type "help" for available commands');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }
}

void _printHelp() {
  print('''
Available Commands:

USER MANAGEMENT:
  CREATE USER <email> <password> [admin|user]
    Example: CREATE USER john@example.com secret123 admin
  
  LIST USERS
    Shows all users in the system
  
  DELETE USER <userId>
    Example: DELETE USER 5d7f9c2b

COLLECTION MANAGEMENT:
  CREATE COLLECTION <ownerId> <collectionName>
    Example: CREATE COLLECTION user123 posts
  
  LIST COLLECTIONS
    Shows all collections
  
  UPDATE RULES <collectionId> <jsonRules>
    Example: UPDATE RULES coll123 {"read":["owner"],"write":["owner"]}

DOCUMENT OPERATIONS:
  CREATE DOCUMENT <collectionId> <userId> <jsonData>
    Example: CREATE DOCUMENT coll123 user456 {"title":"Hello","text":"World"}
  
  READ DOCUMENT <documentId>
    Example: READ DOCUMENT doc789
  
  UPDATE DOCUMENT <documentId> <jsonData>
    Example: UPDATE DOCUMENT doc789 {"title":"Updated"}
  
  DELETE DOCUMENT <documentId>
    Example: DELETE DOCUMENT doc789
  
  LIST DOCUMENTS <collectionId>
    Shows all documents in a collection

OTHER:
  HELP          - Show this help message
  EXIT / QUIT   - Exit CRUD interface

TIPS:
  - JSON data should be properly escaped or use single quotes
  - IDs can be full UUIDs or first 8 characters
  - Timestamps are auto-generated for created_at/updated_at
''');
}

Future<void> _handleCreate(
    List<String> args, DatabaseManager database, String fullCmd) async {
  if (args.isEmpty) {
    print('❌ CREATE requires a resource type (USER or COLLECTION or DOCUMENT)');
    return;
  }

  final resourceType = args[0].toUpperCase();

  try {
    switch (resourceType) {
      case 'USER':
        if (args.length < 3) {
          print('❌ CREATE USER requires: email and password (role optional)');
          print('   Usage: CREATE USER <email> <password> [admin|user]');
          return;
        }
        final email = args[1];
        final password = args[2];
        final role = args.length > 3 ? args[3].toLowerCase() : 'user';

        final user = User(email: email, passwordHash: password, role: role);
        await database.createUser(user);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'CREATE',
          resourceType: 'user',
          resourceId: user.id,
          status: 'success',
          details: 'CREATE USER $email $role',
        ));
        print('✓ User created: ${user.email} (ID: ${user.id.substring(0, 8)})');
        break;

      case 'COLLECTION':
        if (args.length < 3) {
          print('❌ CREATE COLLECTION requires: ownerId and collectionName');
          print('   Usage: CREATE COLLECTION <ownerId> <collectionName>');
          return;
        }
        final ownerId = args[1];
        final collectionName = args[2];

        final collection = Collection(ownerId: ownerId, name: collectionName);
        await database.createCollection(collection);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'CREATE',
          resourceType: 'collection',
          resourceId: collection.id,
          status: 'success',
          details: 'CREATE COLLECTION $collectionName',
        ));
        print(
            '✓ Collection created: $collectionName (ID: ${collection.id.substring(0, 8)})');
        break;

      case 'DOCUMENT':
        if (args.length < 4) {
          print(
              '❌ CREATE DOCUMENT requires: collectionId, userId, and JSON data');
          print('   Usage: CREATE DOCUMENT <collectionId> <userId> <jsonData>');
          return;
        }
        final collectionId = args[1];
        final userId = args[2];
        // Join remaining args as JSON data (handles spaces)
        final jsonStr = args.skip(3).join(' ');
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        final document = Document(
          collectionId: collectionId,
          ownerId: userId,
          data: data,
        );
        await database.createDocument(document);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'CREATE',
          resourceType: 'document',
          resourceId: document.id,
          status: 'success',
          details:
              'CREATE DOCUMENT in $collectionId with data: ${jsonEncode(data)}',
        ));
        print('✓ Document created (ID: ${document.id.substring(0, 8)})');
        break;

      default:
        print('❌ Unknown resource type: $resourceType');
        print('   Try: CREATE USER, CREATE COLLECTION, or CREATE DOCUMENT');
    }
  } catch (e) {
    await logger.logAction(AuditLog(
      userId: 'admin',
      action: 'CREATE',
      resourceType: 'error',
      resourceId: 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
      details: fullCmd,
    ));
    print('❌ Error: $e');
  }
}

Future<void> _handleRead(
    List<String> args, DatabaseManager database, String fullCmd) async {
  if (args.isEmpty) {
    print('❌ READ requires: DOCUMENT <documentId>');
    return;
  }

  final resourceType = args[0].toUpperCase();

  try {
    switch (resourceType) {
      case 'DOCUMENT':
        if (args.length < 2) {
          print('❌ READ DOCUMENT requires: documentId');
          print('   Usage: READ DOCUMENT <documentId>');
          return;
        }
        final documentId = args[1];

        final document = await database.getDocument(documentId);
        if (document == null) {
          print('❌ Document not found');
          await logger.logAction(AuditLog(
            userId: 'admin',
            action: 'READ',
            resourceType: 'document',
            resourceId: documentId,
            status: 'failed',
            errorMessage: 'Document not found',
            details: 'READ DOCUMENT $documentId',
          ));
          return;
        }

        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'READ',
          resourceType: 'document',
          resourceId: documentId,
          status: 'success',
          details: 'READ DOCUMENT $documentId from ${document.collectionId}',
        ));
        print('✓ Document found:');
        print('  ID: ${document.id}');
        print('  Collection: ${document.collectionId}');
        print('  Owner: ${document.ownerId}');
        print('  Data: ${jsonEncode(document.data)}');
        print('  Created: ${document.createdAt}');
        break;

      default:
        print('❌ READ only supports: DOCUMENT');
    }
  } catch (e) {
    await logger.logAction(AuditLog(
      userId: 'admin',
      action: 'READ',
      resourceType: 'document',
      resourceId: args.length > 1 ? args[1] : 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
      details: fullCmd,
    ));
    print('❌ Error: $e');
  }
}

Future<void> _handleUpdate(
    List<String> args, DatabaseManager database, String fullCmd) async {
  if (args.isEmpty) {
    print(
        '❌ UPDATE requires: DOCUMENT <documentId> <jsonData> or RULES <collectionId> <jsonRules>');
    return;
  }

  final resourceType = args[0].toUpperCase();

  try {
    switch (resourceType) {
      case 'DOCUMENT':
        if (args.length < 3) {
          print('❌ UPDATE DOCUMENT requires: documentId and JSON data');
          print('   Usage: UPDATE DOCUMENT <documentId> <jsonData>');
          return;
        }
        final documentId = args[1];
        final jsonStr = args.skip(2).join(' ');
        final newData = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Fetch existing document
        final doc = await database.getDocument(documentId);
        if (doc == null) {
          print('❌ Document not found');
          await logger.logAction(AuditLog(
            userId: 'admin',
            action: 'UPDATE',
            resourceType: 'document',
            resourceId: documentId,
            status: 'failed',
            errorMessage: 'Document not found',
            details: 'UPDATE DOCUMENT $documentId',
          ));
          return;
        }

        // Update data and timestamp
        doc.data.addAll(newData);
        final updatedDoc = Document(
          id: doc.id,
          collectionId: doc.collectionId,
          ownerId: doc.ownerId,
          data: doc.data,
          createdAt: doc.createdAt,
          updatedAt: DateTime.now(),
        );

        await database.updateDocument(updatedDoc);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'UPDATE',
          resourceType: 'document',
          resourceId: documentId,
          status: 'success',
          details: 'UPDATE DOCUMENT $documentId with: ${jsonEncode(newData)}',
        ));
        print('✓ Document updated');
        break;

      case 'RULES':
        if (args.length < 3) {
          print('❌ UPDATE RULES requires: collectionId and JSON rules');
          print('   Usage: UPDATE RULES <collectionId> <jsonRules>');
          return;
        }
        final collectionId = args[1];
        final jsonStr = args.skip(2).join(' ');
        final rules = jsonDecode(jsonStr) as Map<String, dynamic>;

        await database.updateCollectionRules(collectionId, rules);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'UPDATE',
          resourceType: 'collection',
          resourceId: collectionId,
          status: 'success',
          details: 'UPDATE RULES for collection with: ${jsonEncode(rules)}',
        ));
        print('✓ Collection rules updated');
        break;

      default:
        print('❌ UPDATE supports: DOCUMENT, RULES');
    }
  } catch (e) {
    await logger.logAction(AuditLog(
      userId: 'admin',
      action: 'UPDATE',
      resourceType: args.isNotEmpty ? args[0].toLowerCase() : 'unknown',
      resourceId: args.length > 2 ? args[2] : 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
      details: fullCmd,
    ));
    print('❌ Error: $e');
  }
}

Future<void> _handleDelete(
    List<String> args, DatabaseManager database, String fullCmd) async {
  if (args.isEmpty) {
    print('❌ DELETE requires: USER or DOCUMENT');
    return;
  }

  final resourceType = args[0].toUpperCase();

  try {
    switch (resourceType) {
      case 'USER':
        if (args.length < 2) {
          print('❌ DELETE USER requires: userId');
          print('   Usage: DELETE USER <userId>');
          return;
        }
        final userId = args[1];
        await database.deleteUser(userId);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'DELETE',
          resourceType: 'user',
          resourceId: userId,
          status: 'success',
          details: 'DELETE USER $userId',
        ));
        print('✓ User deleted');
        break;

      case 'DOCUMENT':
        if (args.length < 2) {
          print('❌ DELETE DOCUMENT requires: documentId');
          print('   Usage: DELETE DOCUMENT <documentId>');
          return;
        }
        final documentId = args[1];
        await database.deleteDocument(documentId);
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'DELETE',
          resourceType: 'document',
          resourceId: documentId,
          status: 'success',
          details: 'DELETE DOCUMENT $documentId',
        ));
        print('✓ Document deleted');
        break;

      default:
        print('❌ DELETE supports: USER, DOCUMENT');
    }
  } catch (e) {
    await logger.logAction(AuditLog(
      userId: 'admin',
      action: 'DELETE',
      resourceType: args.isNotEmpty ? args[0].toLowerCase() : 'unknown',
      resourceId: args.length > 1 ? args[1] : 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
      details: fullCmd,
    ));
    print('❌ Error: $e');
  }
}

Future<void> _handleList(
    List<String> args, DatabaseManager database, String fullCmd) async {
  if (args.isEmpty) {
    print('❌ LIST requires: USERS, COLLECTIONS, or DOCUMENTS');
    return;
  }

  final resourceType = args[0].toUpperCase();

  try {
    switch (resourceType) {
      case 'USERS':
        final users = await database.getAllUsers();
        if (users.isEmpty) {
          print('No users found');
        } else {
          print('Users (${users.length}):');
          for (final user in users) {
            print(
                '  - ${user.email} (${user.id.substring(0, 8)}) [${user.role}]');
          }
        }
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'LIST',
          resourceType: 'user',
          resourceId: 'all',
          status: 'success',
          details: 'LIST USERS (found ${users.length})',
        ));
        break;

      case 'COLLECTIONS':
        final collections = await database.getAllCollections();
        if (collections.isEmpty) {
          print('No collections found');
        } else {
          print('Collections (${collections.length}):');
          for (final coll in collections) {
            print(
                '  - ${coll.name} (${coll.id.substring(0, 8)}) owner: ${coll.ownerId.substring(0, 8)}');
          }
        }
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'LIST',
          resourceType: 'collection',
          resourceId: 'all',
          status: 'success',
          details: 'LIST COLLECTIONS (found ${collections.length})',
        ));
        break;

      case 'DOCUMENTS':
        if (args.length < 2) {
          print('❌ LIST DOCUMENTS requires: collectionId');
          print('   Usage: LIST DOCUMENTS <collectionId>');
          return;
        }
        final collectionId = args[1];
        final documents = await database.getCollectionDocuments(collectionId);
        if (documents.isEmpty) {
          print('No documents found in collection $collectionId');
        } else {
          print('Documents in $collectionId (${documents.length}):');
          for (final doc in documents) {
            print(
                '  - ${doc.id.substring(0, 8)} owner: ${doc.ownerId.substring(0, 8)} data: ${jsonEncode(doc.data)}');
          }
        }
        await logger.logAction(AuditLog(
          userId: 'admin',
          action: 'LIST',
          resourceType: 'document',
          resourceId: collectionId,
          status: 'success',
          details:
              'LIST DOCUMENTS in $collectionId (found ${documents.length})',
        ));
        break;

      default:
        print('❌ LIST supports: USERS, COLLECTIONS, DOCUMENTS');
    }
  } catch (e) {
    await logger.logAction(AuditLog(
      userId: 'admin',
      action: 'LIST',
      resourceType: args.isNotEmpty ? args[0].toLowerCase() : 'unknown',
      resourceId: 'unknown',
      status: 'failed',
      errorMessage: e.toString(),
      details: fullCmd,
    ));
    print('❌ Error: $e');
  }
}
