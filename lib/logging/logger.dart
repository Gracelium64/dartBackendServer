// lib/logging/logger.dart
// Central logging system for Shadow App Backend
// Explanation for Flutter Developers:
// Logging is crucial for debugging and monitoring. Here we implement:
// 1. In-memory log stream for live tail display
// 2. File-based logging with daily rotation
// 3. 7-day retention policy
// In Flutter, you might use firebase_crashlytics; here we implement it from scratch.

import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import '../database/models.dart';
import '../config.dart';

/// Central logger for the server
class ServerLogger {
  static final ServerLogger _instance = ServerLogger._internal();
  late File _currentLogFile;
  late IOSink _logSink;
  late StreamController<AuditLog> _liveLogStream;
  late List<AuditLog> _recentLogs;
  static const int _maxRecentLogs = 1000; // Keep last 1000 in memory

  factory ServerLogger() {
    return _instance;
  }

  ServerLogger._internal() {
    _recentLogs = [];
    _liveLogStream = StreamController<AuditLog>.broadcast();
  }

  /// Initialize logging system
  Future<void> initialize() async {
    print('[LOG] Initializing logging system...');

    // Create logs directory if needed
    final logsDir = Directory(globalConfig.logFilePath);
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
      print('[LOG] Created logs directory: ${globalConfig.logFilePath}');
    }

    // Create today's log file
    _createTodayLogFile();

    print('[LOG] Logging initialized at ${globalConfig.logFilePath}');

    // Schedule daily cleanup
    _scheduleDailyCleanup();
  }

  /// Create or open today's log file
  void _createTodayLogFile() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logPath =
        path.join(globalConfig.logFilePath, 'shadow_app_$today.log');
    _currentLogFile = File(logPath);
    _logSink = _currentLogFile.openWrite(mode: FileMode.append);
    print('[LOG] Log file: $logPath');
  }

  /// Log an audit action
  Future<void> logAction(AuditLog action) async {
    try {
      // Add to in-memory stream for live tail
      _liveLogStream.add(action);

      // Add to recent logs circular buffer
      _recentLogs.add(action);
      if (_recentLogs.length > _maxRecentLogs) {
        _recentLogs.removeAt(0);
      }

      // Write to file
      final logEntry = _formatLogEntry(action);
      _logSink.writeln(logEntry);
      // Ensure tail readers can see the entry immediately.
      await _logSink.flush();

      // Check if we need to rotate log file (midnight)
      _checkLogRotation();
    } catch (e) {
      print('[LOG ERROR] Failed to log action: $e');
    }
  }

  /// Format log entry for file writing
  String _formatLogEntry(AuditLog action) {
    return [
      action.timestamp.toIso8601String(),
      action.userId,
      action.action,
      '${action.resourceType}:${action.resourceId}',
      action.status,
      action.errorMessage ?? '-',
      action.details ?? '-',
    ].join('\t');
  }

  /// Check if log file needs to be rotated
  void _checkLogRotation() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final expectedPath =
        path.join(globalConfig.logFilePath, 'shadow_app_$today.log');

    if (_currentLogFile.path != expectedPath) {
      // Day has changed, rotate log file
      _logSink.close();
      _createTodayLogFile();
      print('[LOG] Log file rotated');

      // Cleanup old logs
      _cleanupOldLogs();
    }
  }

  /// Get stream of live actions
  Stream<AuditLog> getLiveStream() {
    return _liveLogStream.stream;
  }

  /// Get recent log entries
  List<AuditLog> getRecentLogs({int count = 50}) {
    return _recentLogs
        .skip((_recentLogs.length - count).clamp(0, _recentLogs.length))
        .toList();
  }

  /// Read log file
  Future<List<String>> readLogFile(String date) async {
    final logPath = path.join(globalConfig.logFilePath, 'shadow_app_$date.log');
    final file = File(logPath);

    if (!await file.exists()) {
      return [];
    }

    return await file.readAsLines();
  }

  /// Get all log files in retention period
  Future<List<File>> getLogFiles() async {
    final logsDir = Directory(globalConfig.logFilePath);
    final files = await logsDir.list().toList();

    return files
        .whereType<File>()
        .where((f) => f.path.contains('shadow_app_'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Newest first
  }

  /// Clean up log files older than retention period
  Future<void> _cleanupOldLogs() async {
    try {
      final files = await getLogFiles();
      final now = DateTime.now();
      final retentionDate =
          now.subtract(Duration(days: globalConfig.logRetentionDays));

      for (final file in files) {
        final stat = await file.stat();
        if (stat.modified.isBefore(retentionDate)) {
          await file.delete();
          print('[LOG] Deleted old log file: ${file.path}');
        }
      }
    } catch (e) {
      print('[LOG ERROR] Cleanup failed: $e');
    }
  }

  /// Schedule daily cleanup at midnight
  void _scheduleDailyCleanup() {
    // Calculate time until next midnight
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    // Schedule cleanup
    Timer(timeUntilMidnight, () {
      _cleanupOldLogs();
      _scheduleDailyCleanup(); // Reschedule for next day
    });
  }

  /// Flush logs to disk
  Future<void> flush() async {
    await _logSink.flush();
  }

  /// Close logger (call on shutdown)
  Future<void> close() async {
    await _logSink.flush();
    await _logSink.close();
    await _liveLogStream.close();
  }

  /// Export logs as archive
  Future<String> exportLogsAsArchive() async {
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    final archivePath = path.join(
      globalConfig.logFilePath,
      'exported_logs_$timestamp.tar.gz',
    );

    print('[LOG] Exporting logs as archive...');

    // Get all log files
    final files = await getLogFiles();
    if (files.isEmpty) {
      print('[LOG] No log files to export');
      return archivePath;
    }

    // Create a tar archive
    final archive = Archive();

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final archiveFile = ArchiveFile(
        path.basename(file.path),
        bytes.length,
        bytes,
      );
      archive.addFile(archiveFile);
    }

    // Encode as tar
    final tarBytes = TarEncoder().encode(archive);

    // Compress with gzip
    final gzipBytes = GZipEncoder().encode(tarBytes);

    // Write to file
    final archiveFile = File(archivePath);
    await archiveFile.writeAsBytes(gzipBytes!);

    print(
        '[LOG] Archive created: ${archiveFile.path} (${gzipBytes.length} bytes, ${files.length} files)');
    return archivePath;
  }
}

/// Global logger instance
final logger = ServerLogger();
