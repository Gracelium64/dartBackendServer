/// bin/commands/cli_config.dart
///
/// Configuration and argument parser definitions for the CLI.
/// This module centralizes all command-line argument definitions to keep
/// the main entry point clean and organized.

import 'package:args/args.dart';

/// Defines arguments for the "server" command
///
/// The server command starts the HTTP backend server that listens for API requests.
/// Developers can customize the port, host binding, database location, and logging level.
ArgParser serverCommandParser() {
  return ArgParser()
    ..addOption(
      'port',
      defaultsTo: '8080',
      help: 'Server port to listen on',
    )
    ..addOption(
      'host',
      defaultsTo: '0.0.0.0',
      help:
          'Server host to bind to (0.0.0.0 for public access, 127.0.0.1 for localhost)',
    )
    ..addOption(
      'db-path',
      defaultsTo: 'data/shadow_app.db',
      help: 'Path to SQLite database file',
    )
    ..addOption(
      'log-level',
      defaultsTo: 'INFO',
      help: 'Logging level (DEBUG, INFO, WARN, ERROR)',
    )
    ..addFlag(
      'stop',
      help: 'Stop running server gracefully',
    );
}

/// Defines arguments for the "log-tail" command
///
/// The log-tail command displays and monitors live database audit logs.
/// Similar to Unix 'tail', it can show recent entries and follow new ones in real-time.
ArgParser logTailCommandParser() {
  return ArgParser()
    ..addOption(
      'lines',
      defaultsTo: '50',
      help: 'Number of recent lines to display',
    )
    ..addOption(
      'db-path',
      defaultsTo: 'data/shadow_app.db',
      help: 'Path to SQLite database file (must match server db-path)',
    )
    ..addFlag(
      'follow',
      help: 'Follow new log entries in real-time (like "tail -f")',
    );
}

/// Defines arguments for the "admin" command
///
/// The admin command opens an interactive console for database management.
/// Operators can manage users, collections, documents, and configure permissions.
ArgParser adminCommandParser() {
  return ArgParser()
    ..addOption(
      'admin-key',
      help: 'Admin key for authentication (will prompt if not provided)',
    )
    ..addOption(
      'server-url',
      defaultsTo: 'http://localhost:8080',
      help: 'Backend server URL',
    )
    ..addOption(
      'db-path',
      defaultsTo: 'data/shadow_app.db',
      help: 'Path to SQLite database file (must match server db-path)',
    );
}

/// Usage information for the entire CLI
///
/// Displayed when user runs `dart bin/main.dart --help` or without arguments.
String usageInfo(ArgParser parser) {
  return '''
╔════════════════════════════════════════════════════════════════════════════════╗
║                     Shadow App Backend - CLI Usage                             ║
╚════════════════════════════════════════════════════════════════════════════════╝

SYNOPSIS: dart bin/main.dart <command> [options]

COMMANDS:
  server      Start the HTTP backend server (listens on port 8080 by default)
  log-tail    Monitor live database audit logs in real-time
  admin       Interactive console for database management (users, collections, docs)

GLOBAL OPTIONS:
  --help      Show this help message
  --version   Show version information

QUICK START:

  1. Start the server (Terminal 1):
     dart bin/main.dart server --host 0.0.0.0 --port 8080

  2. Watch logs live (Terminal 2):
     dart bin/main.dart log-tail --follow

  3. Manage database (Terminal 3):
     dart bin/main.dart admin --db-path data/shadow_app.db

DETAILED USAGE:

Server Mode:
  dart bin/main.dart server [--port 8080] [--host 0.0.0.0] [--db-path data/shadow_app.db]
  
  For public network access (LAN/internet):
    --host 0.0.0.0          (binds to all interfaces)
  
  For local-only access (development):
    --host 127.0.0.1        (binds to localhost only)

Log Tail Mode:
  dart bin/main.dart log-tail [--lines 50] [--follow]
  
  --lines 50     Show last 50 log entries (default)
  --follow       Continue to show new entries as they arrive (Ctrl+C to stop)

Admin Mode:
  dart bin/main.dart admin [--db-path data/shadow_app.db]
  
  Opens interactive menu for:
    - User management (list, add, delete, change roles)
    - Audit log viewing
    - CRUD operations (collections, documents)
    - SQL query blocks via CRUD console (`QUERY <SQL>`)
    - System statistics
    - Permission rules configuration
    - Report generation

SQL-LIKE QUERY EXAMPLES (inside admin -> CRUD -> Raw CRUD Commands):
  QUERY SELECT id, owner_id FROM documents LIMIT 10
  QUERY UPDATE users SET role='admin' WHERE email='ops@example.com'
  QUERY DELETE FROM documents WHERE owner_id='legacy_user'; SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5
  QUERY SELECT id FROM documents WHERE owner_id = 'user123' LIMIT 10
  QUERY SELECT json_extract(data, '\$.status') AS status, COUNT(*) AS total FROM documents GROUP BY status
  QUERY CAP 500
  QUERY CAP OFF

  Notes:
    - Up to 5 SQL statements can be sent in one QUERY command
    - Destructive/write SQL is allowed for admin users
    - Row cap defaults to 200 and can be overridden per current session

WORKFLOW EXAMPLE:

  # Terminal 1: Start server with maximum verbosity to all networks
  \$ dart bin/main.dart server --host 0.0.0.0 --port 8080 --db-path data/shadow_app.db

  # Terminal 2: Monitor logs in real-time
  \$ dart bin/main.dart log-tail --follow --lines 100

  # Terminal 3: Perform admin operations
  \$ dart bin/main.dart admin --db-path data/shadow_app.db
    > (now in interactive menu, choose from 1-7)

REMOTE ACCESS (Different Machine):

  1. Find your server IP:
     \$ ifconfig     # macOS/Linux
     \$ ipconfig     # Windows

  2. Use CLI client from another machine:
     \$ cd cli_client
     \$ dart bin/client.dart --server http://YOUR_IP:8080 --email user@ex.com --password pass

DATABASE PATH NOTES:

  - Relative paths are stored in the current working directory
  - On macOS, relative paths are stored in ~/Library/Application Support/ShadowAppBackend/
  - Use --db-path consistently between server and admin to share the same database
  - Absolute paths are used as-is

For more help on specific commands:
  dart bin/main.dart server --help
  dart bin/main.dart log-tail --help
  dart bin/main.dart admin --help

For API documentation and SDK guides, see:
  docs/SDK_GUIDE.md        - REST API and multi-SDK integration
  docs/ARCHITECTURE.md     - System design and data models
  docs/OPERATOR_MANUAL.md  - Detailed operational procedures
  cli_client/README.md     - Remote CLI client usage
''';
}
