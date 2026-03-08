/// bin/commands/server_command.dart
///
/// Handles the "server" command - starts the HTTP backend server.
/// This separates server startup logic from the main CLI entry point,
/// making the code more modular and easier to test.

import 'package:args/args.dart';
import 'package:shadow_app_backend/server.dart' as server;
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../helpers/terminal_ui.dart';

/// Handle the "server" command
///
/// Starts the HTTP backend server and listens for incoming API requests.
/// Developers can customize:
/// - Port: Which port to listen on (default: 8080)
/// - Host: Which interface to bind to (default: 0.0.0.0 for public access)
/// - Database path: Location of SQLite database file
/// - Logging level: Control verbosity of server logs
///
/// Example: dart bin/main.dart server --host 0.0.0.0 --port 8080
Future<void> runServerCommand(ArgResults results) async {
  TerminalUI.printHeader('Starting Shadow App Backend Server');

  // Extract and validate arguments
  final port = int.parse(results['port'] as String);
  final host = results['host'] as String;
  final dbPath = _resolveDbPath(results['db-path'] as String);
  final logLevel = results['log-level'] as String;

  // Display startup configuration
  print('\n📋 Configuration:');
  print('  🌐 Host: $host');
  print('  🔌 Port: $port');
  print('  💾 Database: $dbPath');
  print('  📊 Log Level: $logLevel');

  // Warn user if accidentally setting localhost-only access
  if (host == '127.0.0.1' || host == 'localhost') {
    TerminalUI.printWarning(
      'ℹ️  Server is bound to localhost only.\n'
      '   Use --host 0.0.0.0 for local network/public access.',
    );
  }

  // Start the server
  try {
    print('\n🚀 Server starting...');
    await server.runServer(
      host,
      port,
      dbPathOverride: dbPath,
      logLevelOverride: logLevel,
    );
  } catch (e) {
    TerminalUI.printError('Failed to start server: $e');
    exit(1);
  }
}

/// Resolve database path to handle different OS conventions
///
/// On macOS, relative paths are stored in the application support directory.
/// On other systems, relative paths are used as-is.
/// Absolute paths are always normalized and used directly.
///
/// This ensures consistency when sharing databases between server and admin console.
String _resolveDbPath(String dbPath) {
  // If already absolute, just normalize it
  if (path.isAbsolute(dbPath)) {
    return path.normalize(dbPath);
  }

  // On macOS, use ~/Library/Application Support/ for relative paths
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

  // On Linux/Windows, use relative to current directory
  return path.normalize(dbPath);
}
