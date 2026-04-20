// bin/helpers/report_generator.dart
// Helper functions for generating system reports

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/logging/logger.dart';
import 'package:shadow_app_backend/config.dart';
import 'package:path/path.dart' as path;
import 'terminal_ui.dart';
import 'formatting.dart';

class ReportBundleResult {
  final String bundlePath;
  final int sizeBytes;

  const ReportBundleResult({
    required this.bundlePath,
    required this.sizeBytes,
  });
}

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

/// Export a full administrative report bundle to a selected directory.
Future<ReportBundleResult?> exportAdminReportBundle(
  DatabaseManager database, {
  String? outputDirectory,
}) async {
  TerminalUI.printHeader('Export Admin Report Bundle');

  try {
    final targetDirectory = await _ensureExportDirectory(outputDirectory);
    await logger.flush();

    final generatedAt = DateTime.now();
    final timestamp = _bundleTimestamp(generatedAt);
    final bundleName = 'shadow_admin_report_$timestamp.tar.gz';
    final bundlePath = path.join(targetDirectory.path, bundleName);
    final stagingDirectory =
        await Directory.systemTemp.createTemp('shadow_admin_report_');

    try {
      final manifest = await _buildReportManifest(database, generatedAt);
      await _writeManifestFiles(stagingDirectory.path, manifest, database);

      final archive = Archive();
      await _addDirectoryToArchive(
        archive,
        Directory(stagingDirectory.path),
        archiveRoot: 'report_bundle',
      );

      await _addFileIfExists(
        archive,
        File(globalConfig.dbPath),
        'database/${path.basename(globalConfig.dbPath)}',
      );
      await _addFileIfExists(
        archive,
        File('${globalConfig.dbPath}-wal'),
        'database/${path.basename(globalConfig.dbPath)}-wal',
      );
      await _addFileIfExists(
        archive,
        File('${globalConfig.dbPath}-shm'),
        'database/${path.basename(globalConfig.dbPath)}-shm',
      );

      for (final logFile in await logger.getLogFiles()) {
        await _addFileIfExists(
          archive,
          logFile,
          'logs/${path.basename(logFile.path)}',
        );
      }

      final tarBytes = TarEncoder().encode(archive);
      final gzipBytes = GZipEncoder().encode(tarBytes);
      if (gzipBytes == null) {
        throw StateError('Failed to compress report bundle.');
      }

      final bundleFile = File(bundlePath);
      await bundleFile.writeAsBytes(gzipBytes, flush: true);

      TerminalUI.printSuccess('Report bundle created: $bundlePath');
      TerminalUI.printWarning(
        'Bundle contains sensitive data including password hashes, audit history, and database snapshots.',
      );

      return ReportBundleResult(
        bundlePath: bundlePath,
        sizeBytes: gzipBytes.length,
      );
    } finally {
      if (await Directory(stagingDirectory.path).exists()) {
        await Directory(stagingDirectory.path).delete(recursive: true);
      }
    }
  } catch (e) {
    TerminalUI.printError('Failed to export admin report bundle: $e');
    return null;
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

Future<Directory> _ensureExportDirectory(String? outputDirectory) async {
  final requestedPath = (outputDirectory ?? '').trim();
  final resolvedPath = requestedPath.isEmpty
      ? path.join(path.dirname(globalConfig.dbPath), 'exports')
      : path.normalize(path.absolute(requestedPath));

  final directory = Directory(resolvedPath);
  if (await directory.exists()) {
    return directory;
  }

  await directory.create(recursive: true);
  return directory;
}

Future<Map<String, dynamic>> _buildReportManifest(
  DatabaseManager database,
  DateTime generatedAt,
) async {
  final stats = await database.getDatabaseStats();
  final dbFile = File(globalConfig.dbPath);
  final dbSize = await dbFile.exists() ? await dbFile.length() : 0;
  final logFiles = await logger.getLogFiles();

  var logBytes = 0;
  for (final file in logFiles) {
    if (await file.exists()) {
      logBytes += await file.length();
    }
  }

  return {
    'generated_at': generatedAt.toIso8601String(),
    'database_path': globalConfig.dbPath,
    'logs_path': globalConfig.logFilePath,
    'email_configured': globalConfig.gmailEmail.trim().isNotEmpty,
    'stats': stats,
    'database_size_bytes': dbSize,
    'log_size_bytes': logBytes,
    'log_file_count': logFiles.length,
    'included_tables': [
      'users',
      'collections',
      'documents',
      'audit_log',
      'media_blobs (metadata only)',
    ],
  };
}

Future<void> _writeManifestFiles(
  String stagingPath,
  Map<String, dynamic> manifest,
  DatabaseManager database,
) async {
  await _writeJsonFile(
    path.join(stagingPath, 'manifest.json'),
    manifest,
  );
  await _writeJsonFile(
    path.join(stagingPath, 'database', 'users.json'),
    database.executeRawQuery(
      'SELECT id, email, password_hash, role, created_at, updated_at FROM users ORDER BY created_at DESC',
    ),
  );
  await _writeJsonFile(
    path.join(stagingPath, 'database', 'collections.json'),
    _decodeJsonColumns(
      database.executeRawQuery(
        'SELECT id, owner_id, name, rules, created_at, updated_at FROM collections ORDER BY created_at DESC',
      ),
      const {'rules'},
    ),
  );
  await _writeJsonFile(
    path.join(stagingPath, 'database', 'documents.json'),
    _decodeJsonColumns(
      database.executeRawQuery(
        'SELECT id, collection_id, owner_id, data, created_at, updated_at FROM documents ORDER BY created_at DESC',
      ),
      const {'data'},
    ),
  );
  await _writeJsonFile(
    path.join(stagingPath, 'database', 'audit_log.json'),
    database.executeRawQuery(
      'SELECT id, user_id, action, resource_type, resource_id, status, error_message, details, timestamp FROM audit_log ORDER BY timestamp DESC',
    ),
  );
  await _writeJsonFile(
    path.join(stagingPath, 'database', 'media_metadata.json'),
    database.executeRawQuery(
      'SELECT id, document_id, file_name, mime_type, original_size, compressed_size, compression_algo, created_at FROM media_blobs ORDER BY created_at DESC',
    ),
  );
  await _writeTextFile(
    path.join(stagingPath, 'README.txt'),
    '''Shadow App Backend admin report bundle

Generated: ${manifest['generated_at']}
Database: ${manifest['database_path']}
Logs: ${manifest['logs_path']}

This bundle contains confidential administrative data.
- The report_bundle/database folder contains JSON exports for key tables.
- The archive database folder also contains raw SQLite snapshot files.
- The logs folder contains the current server log files.
''',
  );
}

Future<void> _writeJsonFile(String filePath, Object content) async {
  final file = File(filePath);
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert(content)}\n');
}

Future<void> _writeTextFile(String filePath, String content) async {
  final file = File(filePath);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

List<Map<String, dynamic>> _decodeJsonColumns(
  List<Map<String, dynamic>> rows,
  Set<String> jsonColumns,
) {
  return rows.map((row) {
    final normalized = Map<String, dynamic>.from(row);
    for (final key in jsonColumns) {
      final value = normalized[key];
      if (value is String && value.isNotEmpty) {
        try {
          normalized[key] = jsonDecode(value);
        } catch (_) {
          // Preserve the raw value when decoding fails.
        }
      }
    }
    return normalized;
  }).toList();
}

Future<void> _addDirectoryToArchive(
  Archive archive,
  Directory directory, {
  required String archiveRoot,
}) async {
  await for (final entity
      in directory.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }

    final relativePath = path.relative(entity.path, from: directory.path);
    final archivePath =
        path.join(archiveRoot, relativePath).replaceAll('\\', '/');
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
  }
}

Future<void> _addFileIfExists(
  Archive archive,
  File file,
  String archivePath,
) async {
  if (!await file.exists()) {
    return;
  }

  final bytes = await file.readAsBytes();
  archive.addFile(
    ArchiveFile(archivePath.replaceAll('\\', '/'), bytes.length, bytes),
  );
}

String _bundleTimestamp(DateTime value) {
  final safeIso = value.toIso8601String().replaceAll(':', '-');
  return safeIso.split('.').first;
}
