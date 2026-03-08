/// bin/commands/admin_command.dart
///
/// Handles the "admin" command - interactive database management console.
/// This provides a menu-driven interface for operators to manage users,
/// collections, documents, permissions, and view audit logs.

import 'package:args/args.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/logging/logger.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../helpers/terminal_ui.dart';
import '../helpers/user_management.dart' as user_mgmt;
import '../helpers/document_operations.dart' as doc_ops;
import '../helpers/report_generator.dart' as reports;
import '../helpers/crud_repl.dart';

/// Handle the "admin" command
///
/// Opens an interactive admin console for database management.
/// Operators can:
/// - Manage users (list, add, delete, change roles)
/// - View audit logs
/// - Manage collections and documents
/// - Configure access control rules
/// - Generate reports
///
/// Example: dart bin/main.dart admin --db-path data/shadow_app.db
Future<void> runAdminCommand(ArgResults results) async {
  TerminalUI.printHeader('Admin Console - Shadow App Backend');
  final dbPath = _resolveDbPath(results['db-path'] as String);

  // Initialize database and logging systems
  try {
    print('\n🔧 Initializing database connection...');
    globalConfig = ServerConfig();
    await globalConfig.load();
    globalConfig.dbPath = dbPath;
    database = DatabaseManager();
    await database.initialize(dbPath);
    await logger.initialize();
    TerminalUI.printSuccess('Database connected: $dbPath');
  } catch (e) {
    TerminalUI.printError('Failed to initialize: $e');
    exit(1);
  }

  // Main admin menu loop
  bool running = true;
  while (running) {
    print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║                         Admin Console - Main Menu                               ║
╚════════════════════════════════════════════════════════════════════════════════╝

  1. 👤 Manage Users
  2. 📊 View Audit Log
  3. 📝 Execute CRUD Operations
  4. 📈 View System Stats
  5. 🔐 Configure Collection Rules
  6. 📄 Generate Reports
  7. ❌ Exit

''');

    stdout.write('Enter your choice (1-7): ');
    final choice = stdin.readLineSync();

    try {
      switch (choice) {
        case '1':
          await _adminMenuUsers();
          break;
        case '2':
          await _adminMenuAuditLog();
          break;
        case '3':
          await _adminMenuCrud();
          break;
        case '4':
          await _adminMenuStats();
          break;
        case '5':
          await _adminMenuRules();
          break;
        case '6':
          await _adminMenuReports();
          break;
        case '7':
          running = false;
          break;
        default:
          TerminalUI.printError('Invalid choice. Please enter 1-7.');
      }
    } catch (e) {
      TerminalUI.printError('Operation failed: $e');
    }
  }

  TerminalUI.printSuccess('Admin console closed');
}

/// User management submenu
Future<void> _adminMenuUsers() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              User Management                                   ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('\n1. List Users');
  print('2. Add User');
  print('3. Delete User');
  print('4. Change Role');
  print('5. Back');

  stdout.write('\nEnter choice (1-5): ');
  final choice = stdin.readLineSync();

  switch (choice) {
    case '1':
      await user_mgmt.listUsers(database);
      break;
    case '2':
      await user_mgmt.addUser(database);
      break;
    case '3':
      await user_mgmt.deleteUser(database);
      break;
    case '4':
      await user_mgmt.changeUserRole(database);
      break;
    case '5':
      break;
    default:
      TerminalUI.printError('Invalid choice');
  }
}

/// Audit log viewing submenu
Future<void> _adminMenuAuditLog() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              View Audit Log                                    ║');
  print('╚════════════════════════════════════════════════════════════════╝');

  stdout.write('\nNumber of entries to display [100]: ');
  final limitStr = stdin.readLineSync()?.trim() ?? '100';
  final limit = int.tryParse(limitStr) ?? 100;

  final logs = await database.getAuditLog(limit: limit);

  if (logs.isEmpty) {
    TerminalUI.printWarning('No audit log entries found');
  } else {
    print('\n📊 Audit Log (${logs.length} entries)\n');
    final headers = [
      'Timestamp',
      'User',
      'Action',
      'Resource',
      'Status',
      'Details'
    ];
    final rows = logs
        .map((log) => [
              log.timestamp.toIso8601String().substring(0, 19),
              log.userId.substring(0, 8),
              log.action,
              '${log.resourceType}:${log.resourceId.substring(0, 8)}',
              log.status == 'success'
                  ? '✓ Success'
                  : '✗ Failed${log.errorMessage != null ? " (${log.errorMessage})" : ""}',
              log.details ?? '-',
            ])
        .toList();
    TerminalUI.printTable(headers, rows);
  }
}

/// CRUD operations submenu
Future<void> _adminMenuCrud() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              CRUD Operations                                   ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('\n1. List Collections');
  print('2. Create Collection');
  print('3. Create Document');
  print('4. Read Document');
  print('5. Update Document');
  print('6. Delete Document');
  print('7. List Documents in Collection');
  print('8. Raw CRUD + SQL Query Commands (Interactive Shell)');
  print('9. Back');

  stdout.write('\nEnter choice (1-9): ');
  final choice = stdin.readLineSync();

  switch (choice) {
    case '1':
      await doc_ops.listCollections(database);
      break;
    case '2':
      await doc_ops.createCollection(database);
      break;
    case '3':
      await doc_ops.createDocument(database);
      break;
    case '4':
      await doc_ops.readDocument(database);
      break;
    case '5':
      await doc_ops.updateDocument(database);
      break;
    case '6':
      await doc_ops.deleteDocument(database);
      break;
    case '7':
      await doc_ops.listDocuments(database);
      break;
    case '8':
      await startCrudRepl(database);
      break;
    case '9':
      break;
    default:
      TerminalUI.printError('Invalid choice');
  }
}

/// System statistics submenu
Future<void> _adminMenuStats() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              System Statistics                                 ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  await reports.generateStorageReport(database);
}

/// Collection rules configuration submenu
Future<void> _adminMenuRules() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              Configure Collection Rules                        ║');
  print('╚════════════════════════════════════════════════════════════════╝');

  // List collections
  final collections = await database.getAllCollections();
  if (collections.isEmpty) {
    TerminalUI.printWarning('No collections found. Create a collection first.');
    return;
  }

  print('\n📁 Collections:');
  for (var i = 0; i < collections.length; i++) {
    print(
      '  ${i + 1}. ${collections[i].name} '
      '(${collections[i].id.substring(0, 8)})',
    );
  }

  stdout.write('\nSelect collection number: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  final index = int.tryParse(input);

  if (index == null || index < 1 || index > collections.length) {
    TerminalUI.printError('Invalid selection');
    return;
  }

  final collection = collections[index - 1];
  print('\n📋 Current rules for "${collection.name}":');
  print(jsonEncode(collection.rules));
  print('\n📝 Enter new rules as JSON (or press Enter to keep current):');
  print(
      'Example: {"read":["owner","admin"],"write":["owner"],"public_read":false}');
  stdout.write('\nNew rules: ');
  final rulesStr = stdin.readLineSync()?.trim() ?? '';

  if (rulesStr.isEmpty) {
    print('ℹ️  No changes made');
    return;
  }

  try {
    final newRules = jsonDecode(rulesStr) as Map<String, dynamic>;
    await database.updateCollectionRules(collection.id, newRules);
    TerminalUI.printSuccess(
      'Rules updated for collection "${collection.name}"',
    );
  } catch (e) {
    TerminalUI.printError('Invalid JSON: $e');
  }
}

/// Reports generation submenu
Future<void> _adminMenuReports() async {
  print('\n╔════════════════════════════════════════════════════════════════╗');
  print('║              Generate Reports                                  ║');
  print('╚════════════════════════════════════════════════════════════════╝');
  print('\n1. Export Log Archive');
  print('2. User Activity Report');
  print('3. Storage Usage Report');
  print('4. Back');

  stdout.write('\nEnter choice (1-4): ');
  final choice = stdin.readLineSync();

  switch (choice) {
    case '1':
      await reports.exportLogArchive();
      break;
    case '2':
      await reports.generateUserActivityReport(database);
      break;
    case '3':
      await reports.generateStorageReport(database);
      break;
    case '4':
      break;
    default:
      TerminalUI.printError('Invalid choice');
  }
}

/// Resolve database path to handle different OS conventions
///
/// On macOS, relative paths are stored in the application support directory.
/// On other systems, relative paths are used as-is.
/// Absolute paths are always normalized and used directly.
String _resolveDbPath(String dbPath) {
  if (path.isAbsolute(dbPath)) {
    return path.normalize(dbPath);
  }

  if (Platform.isMacOS) {
    final homeDir = Platform.environment['HOME'];
    if (homeDir != null && homeDir.isNotEmpty) {
      final baseDir = path.join(
        homeDir,
        'Library',
        'Application Support',
        'ShadowAppBackend',
      );
      return path.normalize(path.join(baseDir, dbPath));
    }
  }

  return path.normalize(dbPath);
}
