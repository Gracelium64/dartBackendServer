// bin/main.dart
// Main CLI entrypoint for Shadow App Backend
// Supports three modes: server, log-tail, admin
// Explanation for Flutter Developers:
// This is like the main() entry point in a Flutter app, but for a backend server.
// It handles different commands (like Android intents or deep links) to run different
// parts of the application.

import 'package:args/args.dart';
import 'package:shadow_app_backend/server.dart' as server;
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/logging/logger.dart';
import 'package:shadow_app_backend/config.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;

// Import helper modules
import 'helpers/terminal_ui.dart';
import 'helpers/user_management.dart' as user_mgmt;
import 'helpers/document_operations.dart' as doc_ops;
import 'helpers/report_generator.dart' as reports;

/// Main entry point
Future<void> main(List<String> args) async {
  // Print banner
  TerminalUI.printBanner();

  // Define CLI arguments parser
  final parser = ArgParser()
    ..addCommand('server', _serverCommand())
    ..addCommand('log-tail', _logTailCommand())
    ..addCommand('admin', _adminCommand())
    ..addFlag('help', negatable: false, help: 'Show this help message')
    ..addFlag('version', negatable: false, help: 'Show version');

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (results['version'] as bool) {
      print('Shadow App Backend v0.1.0');
      return;
    }

    final command = results.command;
    if (command == null) {
      _printUsage(parser);
      return;
    }

    switch (command.name) {
      case 'server':
        await _runServer(command);
        break;
      case 'log-tail':
        await _runLogTail(command);
        break;
      case 'admin':
        await _runAdmin(command);
        break;
    }
  } catch (e) {
    TerminalUI.printError('Error: $e');
    exit(1);
  }
}

/// Define server command arguments
ArgParser _serverCommand() {
  return ArgParser()
    ..addOption('port', defaultsTo: '8080', help: 'Server port')
    ..addOption('host', defaultsTo: '0.0.0.0', help: 'Server host')
    ..addOption('db-path',
        defaultsTo: 'data/shadow_app.db', help: 'Path to SQLite database file')
    ..addOption('log-level',
        defaultsTo: 'INFO', help: 'Logging level (DEBUG, INFO, WARN, ERROR)')
    ..addFlag('stop', help: 'Stop running server gracefully');
}

/// Define log-tail command arguments
ArgParser _logTailCommand() {
  return ArgParser()
    ..addOption('lines',
        defaultsTo: '50', help: 'Number of recent lines to display')
    ..addFlag('follow', help: 'Follow new log entries (like tail -f)');
}

/// Define admin command arguments
ArgParser _adminCommand() {
  return ArgParser()
    ..addOption('admin-key',
        help: 'Admin key for authentication (will prompt if not provided)')
    ..addOption('server-url',
        defaultsTo: 'http://localhost:8080', help: 'Backend server URL');
}

void _printUsage(ArgParser parser) {
  print('''
Usage: dart bin/main.dart <command> [options]

Commands:
  server    Start the backend server
  log-tail  Monitor live database action logs
  admin     Open admin console (CRUD management)

Options:
${parser.usage}

Examples:
  # Start server on port 8080
  dart bin/main.dart server --port 8080

  # Monitor logs in real-time
  dart bin/main.dart log-tail --follow

  # Open admin console
  dart bin/main.dart admin --admin-key xyz123

For detailed help on each command:
  dart bin/main.dart server --help
  dart bin/main.dart log-tail --help
  dart bin/main.dart admin --help
  ''');
}

/// Run server mode
Future<void> _runServer(ArgResults results) async {
  TerminalUI.printHeader('Starting Shadow App Backend Server');

  final port = int.parse(results['port'] as String);
  final host = results['host'] as String;
  final dbPath = results['db-path'] as String;
  final logLevel = results['log-level'] as String;

  print('\nConfiguration:');
  print('  Host: $host');
  print('  Port: $port');
  print('  Database: $dbPath');
  print('  Log Level: $logLevel');

  try {
    await server.runServer(host, port,
        dbPathOverride: dbPath, logLevelOverride: logLevel);
  } catch (e) {
    TerminalUI.printError('Failed to start server: $e');
    exit(1);
  }
}

/// Run log-tail mode
Future<void> _runLogTail(ArgResults results) async {
  TerminalUI.printHeader('Live Action Log - Shadow App Backend');

  final lines = int.parse(results['lines'] as String);
  final follow = results['follow'] as bool;

  // Initialize config and logger
  try {
    globalConfig = ServerConfig();
    await globalConfig.load();
    await logger.initialize();
  } catch (e) {
    TerminalUI.printError('Failed to initialize logging system: $e');
    exit(1);
  }

  print(
      '''\nDisplaying recent $lines log entries${follow ? ' (following new entries...)' : ''}\n''');

  // Get most recent log file
  final logFiles = await logger.getLogFiles();
  if (logFiles.isEmpty) {
    TerminalUI.printWarning('No log files found');
    return;
  }

  final latestLogFile = logFiles.first;
  print('Reading: ${path.basename(latestLogFile.path)}\n');

  // Read and display last N lines
  final allLines = await latestLogFile.readAsLines();
  final startIndex = (allLines.length - lines).clamp(0, allLines.length);
  final recentLines = allLines.sublist(startIndex);

  for (final line in recentLines) {
    print(line);
  }

  // Follow mode - watch for new lines
  if (follow) {
    print('\n--- Following new entries (Ctrl+C to stop) ---\n');

    var lastLineCount = allLines.length;

    // Poll the file every second for new lines
    while (true) {
      await Future.delayed(Duration(seconds: 1));

      try {
        final currentLines = await latestLogFile.readAsLines();
        if (currentLines.length > lastLineCount) {
          final newLines = currentLines.sublist(lastLineCount);
          for (final line in newLines) {
            print(line);
          }
          lastLineCount = currentLines.length;
        }
      } catch (e) {
        // File might be rotated, try to get new file
        final updatedLogFiles = await logger.getLogFiles();
        if (updatedLogFiles.isNotEmpty &&
            updatedLogFiles.first.path != latestLogFile.path) {
          print(
              '\n--- Log file rotated to ${path.basename(updatedLogFiles.first.path)} ---\n');
          break;
        }
      }
    }
  }
}

/// Run admin console mode
Future<void> _runAdmin(ArgResults results) async {
  TerminalUI.printHeader('Admin Console - Shadow App Backend');

  // Initialize config, database, and logger
  try {
    print('\nInitializing database connection...');
    globalConfig = ServerConfig();
    await globalConfig.load();
    database = DatabaseManager();
    await database.initialize(globalConfig.dbPath);
    await logger.initialize();
    TerminalUI.printSuccess('Database connected: ${globalConfig.dbPath}');
  } catch (e) {
    TerminalUI.printError('Failed to initialize: $e');
    exit(1);
  }

  // Admin menu loop
  bool running = true;
  while (running) {
    print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║                        Admin Console Main Menu                                  ║
╚════════════════════════════════════════════════════════════════════════════════╝

1. Manage Users
2. View Audit Log
3. Execute CRUD Operations
4. View System Stats
5. Configure Collection Rules
6. Generate Reports
7. Exit

''');

    print('Enter your choice (1-7): ');
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
          TerminalUI.printError('Invalid choice');
      }
    } catch (e) {
      TerminalUI.printError('Operation failed: $e');
    }
  }

  TerminalUI.printSuccess('Admin console closed');
}

Future<void> _adminMenuUsers() async {
  print('\n[Admin] Manage Users');
  print('1. List Users');
  print('2. Add User');
  print('3. Delete User');
  print('4. Change Role');
  print('5. Back');

  print('\nEnter choice (1-5): ');
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

Future<void> _adminMenuAuditLog() async {
  print('\n[Admin] View Audit Log');
  print('\nNumber of entries to display [100]: ');
  final limitStr = stdin.readLineSync()?.trim() ?? '100';
  final limit = int.tryParse(limitStr) ?? 100;

  final logs = await database.getAuditLog(limit: limit);

  if (logs.isEmpty) {
    TerminalUI.printWarning('No audit log entries found');
  } else {
    print('\n--- Audit Log (${logs.length} entries) ---\n');
    final headers = ['Timestamp', 'User', 'Action', 'Resource', 'Status'];
    final rows = logs
        .map((log) => [
              log.timestamp.toIso8601String().substring(0, 19),
              log.userId.substring(0, 8),
              log.action,
              '${log.resourceType}:${log.resourceId.substring(0, 8)}',
              log.status == 'success'
                  ? '✓'
                  : '✗${log.errorMessage != null ? " (${log.errorMessage})" : ""}',
            ])
        .toList();
    TerminalUI.printTable(headers, rows);
  }
}

Future<void> _adminMenuCrud() async {
  print('\n[Admin] CRUD Operations');
  print('1. List Collections');
  print('2. Create Collection');
  print('3. Create Document');
  print('4. Read Document');
  print('5. Update Document');
  print('6. Delete Document');
  print('7. List Documents in Collection');
  print('8. Back');

  print('\nEnter choice (1-8): ');
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
      break;
    default:
      TerminalUI.printError('Invalid choice');
  }
}

Future<void> _adminMenuStats() async {
  await reports.generateStorageReport(database);
}

Future<void> _adminMenuRules() async {
  print('\n[Admin] Configure Collection Rules');

  // List collections
  final collections = await database.getAllCollections();
  if (collections.isEmpty) {
    TerminalUI.printWarning('No collections found. Create a collection first.');
    return;
  }

  print('\n--- Collections ---');
  for (var i = 0; i < collections.length; i++) {
    print(
        '\${i + 1}. \${collections[i].name} (\${collections[i].id.substring(0, 8)})');
  }

  print('\nSelect collection number: ');
  final input = stdin.readLineSync()?.trim() ?? '';
  final index = int.tryParse(input);

  if (index == null || index < 1 || index > collections.length) {
    TerminalUI.printError('Invalid selection');
    return;
  }

  final collection = collections[index - 1];
  print(
      '\nCurrent rules for "\${collection.name}":\n\${jsonEncode(collection.rules)}');
  print('\nEnter new rules as JSON (or press Enter to keep current):\n');
  print(
      'Example: {"read":["owner","admin"],"write":["owner"],"public_read":false}');
  print('\nNew rules: ');
  final rulesStr = stdin.readLineSync()?.trim() ?? '';

  if (rulesStr.isEmpty) {
    print('No changes made');
    return;
  }

  try {
    final newRules = jsonDecode(rulesStr) as Map<String, dynamic>;
    await database.updateCollectionRules(collection.id, newRules);
    TerminalUI.printSuccess(
        'Rules updated for collection "\${collection.name}"');
  } catch (e) {
    TerminalUI.printError('Invalid JSON: \$e');
  }
}

Future<void> _adminMenuReports() async {
  print('\n[Admin] Generate Reports');
  print('1. Export Log Archive');
  print('2. User Activity Report');
  print('3. Storage Usage Report');
  print('4. Back');

  print('\nEnter choice (1-4): ');
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
