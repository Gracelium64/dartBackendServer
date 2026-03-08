/// bin/main.dart
///
/// ╔════════════════════════════════════════════════════════════════════════════╗
/// ║               Shadow App Backend - CLI Entry Point                         ║
/// ║                                                                            ║
/// ║  A transparent, educational backend server written entirely in Dart       ║
/// ║  for Flutter developers to learn backend development.                    ║
/// ╚════════════════════════════════════════════════════════════════════════════╝
///
/// OVERVIEW:
/// This CLI provides three main commands for backend development and operations:
///
/// 1. SERVER MODE
///    Start the HTTP server that handles API requests from clients.
///    Example: dart bin/main.dart server --host 0.0.0.0 --port 8080
///
/// 2. LOG-TAIL MODE
///    Monitor live audit logs of database operations in real-time.
///    Similar to Unix 'tail -f' command.
///    Example: dart bin/main.dart log-tail --follow
///
/// 3. ADMIN MODE
///    Interactive console for database management and operations.
///    Example: dart bin/main.dart admin --db-path data/shadow_app.db
///
/// MODULAR ARCHITECTURE:
/// Each command is implemented in separate modules to maintain clean separation
/// of concerns and improve maintainability. See bin/commands/ directory.

import 'package:args/args.dart';
import 'dart:io';
import 'dart:async';
import 'package:shadow_app_backend/server.dart' as server;

<<<<<<< HEAD
// Import command and configuration modules
import 'commands/cli_config.dart';
import 'commands/server_command.dart';
import 'commands/log_tail_command.dart';
import 'commands/admin_command.dart';
import 'helpers/terminal_ui.dart';
=======
/// ASCII art and UI utilities for styled terminal output
class TerminalUI {
  static final _pen = AnsiPen()..blue();
  static final _penGreen = AnsiPen()..green();
  static final _penRed = AnsiPen()..red();
  static final _penYellow = AnsiPen()..yellow();
>>>>>>> 745f19928406396794f44412fae890877fe1f158

/// Application version
const String appVersion = '0.1.0';

/// Main entry point for the Shadow App Backend CLI
///
/// This function maintains a clean, readable structure by delegating to
/// separate command modules rather than implementing everything inline.
/// Each command has its own parser configuration and handler function.
Future<void> main(List<String> args) async {
  // Print banner for visual feedback
  TerminalUI.printBanner();

  // Create the main argument parser - each command defines its own options
  final parser = ArgParser()
    ..addCommand('server', serverCommandParser())
    ..addCommand('log-tail', logTailCommandParser())
    ..addCommand('admin', adminCommandParser())
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show help message',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show version',
    );

  try {
    // Parse provided arguments
    final results = parser.parse(args);

    // Handle global flags
    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    if (results['version'] as bool) {
      print('Shadow App Backend v$appVersion');
      return;
    }

    // Get the command (if any)
    final command = results.command;
    if (command == null) {
      _printUsage(parser);
      return;
    }

    // Dispatch to the appropriate command handler
    switch (command.name) {
      case 'server':
        await runServerCommand(command);
        break;
      case 'log-tail':
        await runLogTailCommand(command);
        break;
      case 'admin':
        await runAdminCommand(command);
        break;
      default:
        TerminalUI.printError('Unknown command: ${command.name}');
        _printUsage(parser);
        exit(1);
    }
  } on FormatException catch (e) {
    // Handle argument parsing errors
    TerminalUI.printError('Invalid arguments: ${e.message}');
    exit(1);
  } catch (e) {
    // Handle unexpected errors
    TerminalUI.printError('Unexpected error: $e');
    exit(1);
  }
}

<<<<<<< HEAD
/// Print usage information
void _printUsage(ArgParser parser) {
  print(usageInfo(parser));
=======
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

  // Start the actual server
  try {
    await server.runServer(host, port);
  } catch (e) {
    TerminalUI.printError('Failed to start server: $e');
    exit(1);
  }
}

/// Run log-tail mode
Future<void> _runLogTail(ArgResults results) async {
  TerminalUI.printHeader('Live Action Log - Shadow App Backend');

  final lines = int.parse(results['lines'] as String);
  final follow = results['follow'] as bool? ?? false;

  print(
      '''\nDisplaying recent $lines log entries${follow ? ' (following new entries...)' : ''}

''');

  // Print example headers
  final headers = [
    'Timestamp',
    'User',
    'Action',
    'Resource',
    'Status',
  ];

  // Print example data (placeholder)
  final exampleRows = [
    ['2026-02-14T10:30:05Z', 'user@example.com', 'LOGIN', 'user:user-123', '✓'],
    ['2026-02-14T10:30:15Z', 'user@example.com', 'CREATE', 'doc:doc-456', '✓'],
    ['2026-02-14T10:30:22Z', 'admin@example.com', 'READ', 'doc:doc-456', '✓'],
  ];

  TerminalUI.printTable(headers, exampleRows);

  print('\n[PLACEHOLDER] Live log tail would display here');
  print('[PLACEHOLDER] Press Ctrl+C to stop');

  // Keep running
  await Future.delayed(Duration(days: 365));
}

/// Run admin console mode
Future<void> _runAdmin(ArgResults results) async {
  TerminalUI.printHeader('Admin Console - Shadow App Backend');

  var adminKey = results['admin-key'] as String?;
  final serverUrl = results['server-url'] as String;

  if (adminKey == null || adminKey.isEmpty) {
    print('\nEnter admin key (shown on server startup): ');
    adminKey = stdin.readLineSync() ?? '';
  }

  print('\nConnecting to $serverUrl...');
  TerminalUI.printSuccess('Connected to server');

  // Admin menu loop
  bool running = true;
  while (running) {
    print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║                        Admin Console Main Menu                                  ║
╚════════════════════════════════════════════════════════════════════════════════╝

1. Manage Users
2. View Audit Log
3. Execute Raw CRUD
4. View System Stats
5. Configure Collection Rules
6. Generate Reports
7. Exit

''');

    print('Enter your choice (1-7): ');
    final choice = stdin.readLineSync();

    switch (choice) {
      case '1':
        _adminMenuUsers();
        break;
      case '2':
        _adminMenuAuditLog();
        break;
      case '3':
        _adminMenuCrud();
        break;
      case '4':
        _adminMenuStats();
        break;
      case '5':
        _adminMenuRules();
        break;
      case '6':
        _adminMenuReports();
        break;
      case '7':
        running = false;
        break;
      default:
        TerminalUI.printError('Invalid choice');
    }
  }

  TerminalUI.printSuccess('Admin console closed');
}

void _adminMenuUsers() {
  print('\n[Admin] Manage Users');
  print('1. List Users');
  print('2. Add User');
  print('3. Delete User');
  print('4. Change Role');

  print('Enter choice (1-4): ');
  stdin.readLineSync();
  print('[PLACEHOLDER] Admin user management would go here');
}

void _adminMenuAuditLog() {
  print('\n[Admin] View Audit Log');
  print('[PLACEHOLDER] Audit log viewer would go here');
}

void _adminMenuCrud() {
  print('\n[Admin] Execute Raw CRUD');
  print('1. Create Document');
  print('2. Read Document');
  print('3. Update Document');
  print('4. Delete Document');
  print('5. List Collection');

  print('Enter choice (1-5): ');
  stdin.readLineSync();
  print('[PLACEHOLDER] CRUD executor would go here');
}

void _adminMenuStats() {
  print('\n[Admin] System Statistics');

  final headers = ['Metric', 'Value'];
  final rows = [
    ['Total Users', '42'],
    ['Total Collections', '15'],
    ['Total Documents', '8,432'],
    ['Media Storage', '2.3 GB'],
    ['Database Size', '2.5 GB'],
    ['Log Files Size', '1.2 GB'],
    ['Server Uptime', '72 days 15 hours'],
    ['Database Status', '✓ Healthy'],
  ];

  TerminalUI.printTable(headers, rows);
}

void _adminMenuRules() {
  print('\n[Admin] Configure Collection Rules');
  print('[PLACEHOLDER] Permission rule editor would go here');
}

void _adminMenuReports() {
  print('\n[Admin] Generate Reports');
  print('1. Export Monthly Logs');
  print('2. User Activity Report');
  print('3. Storage Usage Report');

  print('Enter choice (1-3): ');
  stdin.readLineSync();
  print('[PLACEHOLDER] Report generator would go here');
>>>>>>> 745f19928406396794f44412fae890877fe1f158
}
