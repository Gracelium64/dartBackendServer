/// bin/commands/log_tail_command.dart
///
/// Handles the "log-tail" command - displays and monitors live audit logs.
/// This command is similar to Unix 'tail' but for database audit trails.
/// It can display recent log entries and continuously monitor new ones in real-time.

import 'package:args/args.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/database/models.dart';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import '../helpers/terminal_ui.dart';

/// Handle the "log-tail" command
///
/// Displays live audit logs of all database operations. This is useful for:
/// - Monitoring what users are doing
/// - Debugging failed operations
/// - Verifying that CRUD commands were executed
/// - Real-time system monitoring
///
/// Similar to Unix 'tail -f', can follow new entries as they arrive.
///
/// Example: dart bin/main.dart log-tail --follow --lines 100
Future<void> runLogTailCommand(ArgResults results) async {
  TerminalUI.printHeader('Live Action Log - Shadow App Backend');

  // Extract arguments
  final lines = int.parse(results['lines'] as String);
  final follow = results['follow'] as bool;
  final dbPath = _resolveDbPath(results['db-path'] as String);

  // Initialize database connection (source of truth for audit events)
  try {
    print('\n🔧 Initializing audit log reader...');
    globalConfig = ServerConfig();
    await globalConfig.load();
    globalConfig.dbPath = dbPath;
    database = DatabaseManager();
    await database.initialize(dbPath);
    TerminalUI.printSuccess('Audit log reader initialized');
  } catch (e) {
    TerminalUI.printError('Failed to initialize audit log reader: $e');
    exit(1);
  }

  print(
    '\n📊 Displaying recent $lines log entries'
    '${follow ? ' (following new entries...)' : ''}\n',
  );
  print('📁 Database: $dbPath\n');
  print('─' * 120);

  final initialLogs = await database.getAuditLog(limit: lines);
  for (final log in initialLogs.reversed) {
    _printLogLine(_formatAuditLogLine(log));
  }

  // Follow mode - watch for new lines
  if (follow) {
    print('─' * 120);
    print('\n👀 Following new entries (press Ctrl+C to stop)\n');

    final seenIds = initialLogs.map((l) => l.id).toSet();

    // Poll audit table every second for new entries.
    while (true) {
      await Future.delayed(Duration(seconds: 1));

      final latest = await database.getAuditLog(limit: 200);
      final newLogs = latest.where((entry) => !seenIds.contains(entry.id));

      for (final log in newLogs.toList().reversed) {
        _printLogLine(_formatAuditLogLine(log));
        seenIds.add(log.id);

        // Cap memory usage in very long sessions.
        if (seenIds.length > 5000) {
          final keep = latest.map((e) => e.id).toSet();
          seenIds
            ..clear()
            ..addAll(keep);
        }
      }
    }
  }

  database.close();
}

String _formatAuditLogLine(AuditLog log) {
  final details = log.details ?? '-';
  final error = log.errorMessage ?? '-';
  return [
    log.timestamp.toIso8601String(),
    log.userId,
    log.action,
    '${log.resourceType}:${log.resourceId}',
    log.status,
    error,
    details,
  ].join('\t');
}

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

/// Print a log line with color coding based on status
///
/// Successful operations are printed in green, failures in red.
/// This makes it easier to spot issues at a glance.
void _printLogLine(String line) {
  // Color code based on status
  if (line.contains('success')) {
    print('\x1B[32m✓ $line\x1B[0m'); // Green
  } else if (line.contains('failed')) {
    print('\x1B[31m✗ $line\x1B[0m'); // Red
  } else {
    print(line);
  }
}
