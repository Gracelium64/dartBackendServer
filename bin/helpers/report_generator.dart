// bin/helpers/report_generator.dart
// Helper functions for generating system reports

import 'dart:io';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/logging/logger.dart';
import 'package:shadow_app_backend/config.dart';
import 'terminal_ui.dart';
import 'formatting.dart';

/// Export all logs as a compressed archive
Future<void> exportLogArchive() async {
  TerminalUI.printHeader('Export Log Archive');

  try {
    final archivePath = await logger.exportLogsAsArchive();
    TerminalUI.printSuccess('Log archive created: $archivePath');
  } catch (e) {
    TerminalUI.printError('Failed to export logs: $e');
  }
}

/// Generate user activity report from audit log
Future<void> generateUserActivityReport(DatabaseManager database) async {
  TerminalUI.printHeader('User Activity Report');

  try {
    final logs = await database.getAuditLog(limit: 10000);

    if (logs.isEmpty) {
      TerminalUI.printWarning('No activity logs found');
      return;
    }

    // Count actions per user
    final activityMap = <String, int>{};
    for (final log in logs) {
      activityMap[log.userId] = (activityMap[log.userId] ?? 0) + 1;
    }

    // Sort by activity count
    final sortedEntries = activityMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Print top users
    final rows = sortedEntries.take(20).map((entry) {
      return [entry.key, entry.value.toString()];
    }).toList();

    TerminalUI.printTable(['User ID', 'Actions'], rows);
    TerminalUI.printSuccess('Total actions: ${logs.length}');
    TerminalUI.printSuccess('Unique users: ${activityMap.length}');
  } catch (e) {
    TerminalUI.printError('Failed to generate report: $e');
  }
}

/// Generate storage usage report
Future<void> generateStorageReport(DatabaseManager database) async {
  TerminalUI.printHeader('Storage Usage Report');

  try {
    final stats = await database.getDatabaseStats();

    // Calculate database file size
    var dbSize = 0;
    final dbFile = File(globalConfig.dbPath);
    if (await dbFile.exists()) {
      dbSize = await dbFile.length();
    }

    // Calculate log files size
    var logSize = 0;
    final logFiles = await logger.getLogFiles();
    for (final file in logFiles) {
      if (await file.exists()) {
        logSize += await file.length();
      }
    }

    print('\n${'=' * 70}');
    print('Database Records:');
    print('  Users:       ${stats['user_count']}');
    print('  Collections: ${stats['collection_count']}');
    print('  Documents:   ${stats['document_count']}');
    print('  Media:       ${stats['media_blob_count']}');
    print('');
    print('Storage:');
    print('  Database:    ${formatBytes(dbSize)}');
    print('  Logs:        ${formatBytes(logSize)}');
    print('  Total:       ${formatBytes(dbSize + logSize)}');
    print('');
    print('Paths:');
    print('  Database:    ${globalConfig.dbPath}');
    print('  Logs:        ${globalConfig.logFilePath}');
    print('=' * 70);
  } catch (e) {
    TerminalUI.printError('Failed to generate report: $e');
  }
}
