// bin/helpers/terminal_ui.dart
// Terminal UI utilities for styled terminal output
// Handles colored text, ASCII tables, banners, and status messages

import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

/// ASCII art and UI utilities for styled terminal output
class TerminalUI {
  static final _pen = AnsiPen()..blue();
  static final _penGreen = AnsiPen()..green();
  static final _penRed = AnsiPen()..red();
  static final _penYellow = AnsiPen()..yellow();

  /// Print the Shadow App banner
  static void printBanner() {
    print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║                                                                                ║
║                    🚀 Shadow App Backend Server v0.1.0 🚀                      ║
║                                                                                ║
║                    A Dart Learning Backend for Flutter Developers              ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
    ''');
  }

  /// Print a blue header with underline
  static void printHeader(String text) {
    print('\n${_pen(text)}');
    print(_pen('═' * text.length));
  }

  /// Print success message with green checkmark
  static void printSuccess(String text) {
    print('${_penGreen('✓')} $text');
  }

  /// Print error message with red X
  static void printError(String text) {
    print('${_penRed('✗')} $text');
  }

  /// Print warning message with yellow icon
  static void printWarning(String text) {
    print('${_penYellow('⚠')} $text');
  }

  /// Print an ASCII table with headers and rows
  ///
  /// Example:
  /// ```dart
  /// TerminalUI.printTable(
  ///   ['ID', 'Name', 'Email'],
  ///   [
  ///     ['1', 'John', 'john@example.com'],
  ///     ['2', 'Jane', 'jane@example.com'],
  ///   ]
  /// );
  /// ```
  static void printTable(List<String> headers, List<List<String>> rows) {
    // Calculate column widths based on content
    final widths = <int>[];
    for (int i = 0; i < headers.length; i++) {
      widths.add(headers[i].length);
      for (final row in rows) {
        if (i < row.length) {
          widths[i] = widths[i] > row[i].length ? widths[i] : row[i].length;
        }
      }
    }

    // Print header
    final headerLine = headers
        .asMap()
        .entries
        .map((e) => e.value.padRight(widths[e.key]))
        .join(' │ ');
    print('┌─${headerLine.replaceAll(' │ ', '─┬─')}─┐');
    print('│ $headerLine │');
    print('├─${headerLine.replaceAll(' │ ', '─┼─')}─┤');

    // Print rows
    for (final row in rows) {
      final rowLine = row
          .asMap()
          .entries
          .map((e) => (e.value).padRight(widths[e.key]))
          .join(' │ ');
      print('│ $rowLine │');
    }

    print('└─${headerLine.replaceAll(' │ ', '─┴─')}─┘');
  }

  /// Print a simple menu with numbered options
  /// Returns the user's choice (1-indexed)
  static int printMenu(String title, List<String> options) {
    printHeader(title);
    for (int i = 0; i < options.length; i++) {
      print('${i + 1}. ${options[i]}');
    }
    stdout.write('\nSelect option: ');
    final input = stdin.readLineSync() ?? '';
    return int.tryParse(input) ?? 0;
  }

  /// Prompt user for input with a message
  static String prompt(
    String message, {
    bool required = true,
    String? defaultValue,
  }) {
    final suffix = defaultValue != null && defaultValue.isNotEmpty
        ? ' [$defaultValue]'
        : '';
    stdout.write('$message$suffix: ');
    final input = stdin.readLineSync() ?? '';
    final resolved =
        input.isEmpty && defaultValue != null ? defaultValue : input;
    if (required && resolved.isEmpty) {
      printError('This field is required');
      return prompt(
        message,
        required: required,
        defaultValue: defaultValue,
      );
    }
    return resolved;
  }

  /// Prompt for password (doesn't hide input, but labels it as password)
  static String promptPassword(
    String message, {
    bool allowEmpty = false,
  }) {
    final suffix =
        allowEmpty ? ' (hidden, leave blank to keep current)' : ' (hidden)';
    stdout.write('$message$suffix: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    print(''); // New line after password
    if (!allowEmpty && password.isEmpty) {
      printError('This field is required');
      return promptPassword(message, allowEmpty: allowEmpty);
    }
    return password;
  }

  /// Prompt for confirmation (yes/no)
  static bool confirm(String message) {
    stdout.write('$message (yes/no): ');
    final input = (stdin.readLineSync() ?? '').toLowerCase();
    return input == 'yes' || input == 'y';
  }
}
