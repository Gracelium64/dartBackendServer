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

// Import command and configuration modules
import 'commands/cli_config.dart';
import 'commands/server_command.dart';
import 'commands/log_tail_command.dart';
import 'commands/admin_command.dart';
import 'helpers/terminal_ui.dart';
import 'package:shadow_app_backend/logging/logger.dart';

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
        await runZonedGuarded(
          () async {
            await runServerCommand(command);
          },
          (error, stackTrace) {
            stderr.writeln('Unhandled server zone error: $error');
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              parent.print(zone, line);
              unawaited(
                logger.logConsoleMessage(
                  line,
                  source: 'server-terminal',
                ),
              );
            },
          ),
        );
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

/// Print usage information
void _printUsage(ArgParser parser) {
  print(usageInfo(parser));
}
