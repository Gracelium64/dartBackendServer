/// bin/commands/log_tail_command.dart
///
/// Handles the "log-tail" command - displays and monitors live audit logs.
/// This command is similar to Unix 'tail' but for database audit trails.
/// It can display recent log entries and continuously monitor new ones in real-time.

import 'package:args/args.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:shadow_app_backend/logging/logger.dart';
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

  // Initialize logging system
  try {
    print('\n🔧 Initializing logging system...');
    globalConfig = ServerConfig();
    await globalConfig.load();
    await logger.initialize();
    TerminalUI.printSuccess('Logging initialized');
  } catch (e) {
    TerminalUI.printError('Failed to initialize logging: $e');
    exit(1);
  }

  print(
    '\n📊 Displaying recent $lines log entries'
    '${follow ? ' (following new entries...)' : ''}\n',
  );

  // Get most recent log file
  final logFiles = await logger.getLogFiles();
  if (logFiles.isEmpty) {
    TerminalUI.printWarning('No log files found');
    return;
  }

  final latestLogFile = logFiles.first;
  print('📁 Reading: ${path.basename(latestLogFile.path)}\n');
  print('─' * 120);

  // Read and display last N lines
  final allLines = await latestLogFile.readAsLines();
  final startIndex = (allLines.length - lines).clamp(0, allLines.length);
  final recentLines = allLines.sublist(startIndex);

  for (final line in recentLines) {
    _printLogLine(line);
  }

  // Follow mode - watch for new lines
  if (follow) {
    print('─' * 120);
    print('\n👀 Following new entries (press Ctrl+C to stop)\n');

    var lastLineCount = allLines.length;

    // Poll the file every second for new lines
    while (true) {
      await Future.delayed(Duration(seconds: 1));

      try {
        final currentLines = await latestLogFile.readAsLines();
        if (currentLines.length > lastLineCount) {
          final newLines = currentLines.sublist(lastLineCount);
          for (final line in newLines) {
            _printLogLine(line);
          }
          lastLineCount = currentLines.length;
        }
      } catch (e) {
        // File might be rotated, try to get new file
        final updatedLogFiles = await logger.getLogFiles();
        if (updatedLogFiles.isNotEmpty &&
            updatedLogFiles.first.path != latestLogFile.path) {
          print(
            '\n🔄 Log file rotated to ${path.basename(updatedLogFiles.first.path)}\n',
          );
          break;
        }
      }
    }
  }
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
