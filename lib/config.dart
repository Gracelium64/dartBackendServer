// lib/config.dart
// Configuration management for Shadow App Backend
// This file handles loading settings from environment variables and config files

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Main configuration class that holds all server settings
/// Explanation for Flutter Developers:
/// This is similar to how you'd manage app configuration in Flutter—load settings
/// at startup and keep them accessible throughout the app's lifetime.
class ServerConfig {
  late String serverHost;
  late int serverPort;
  late String dbPath;
  late String jwtSecret;
  late int jwtExpiryHours;
  late String logFilePath;
  late int logRetentionDays;
  late String logLevel;
  late String gmailEmail;
  late String gmailPassword;
  late bool enableCors;
  late bool enableWal;

  /// Load configuration from environment or config file
  Future<void> load() async {
    // Try to load from config.yaml first
    final configFile = File('config.yaml');
    if (await configFile.exists()) {
      final yaml = loadYaml(await configFile.readAsString()) as YamlMap?;
      if (yaml != null) {
        _loadFromYaml(yaml);
      } else {
        _loadDefaults();
      }
    } else {
      // Fall back to environment variables or defaults
      _loadDefaults();
    }

    _normalizePaths();
  }

  /// Load configuration from YAML map
  void _loadFromYaml(YamlMap yaml) {
    final server = yaml['server'] as YamlMap?;
    final database = yaml['database'] as YamlMap?;
    final logging = yaml['logging'] as YamlMap?;
    final auth = yaml['auth'] as YamlMap?;
    final email = yaml['email'] as YamlMap?;

    // Server settings
    serverHost = server?['host'] as String? ?? '0.0.0.0';
    serverPort = server?['port'] as int? ?? 8080;
    enableCors = server?['enable_cors'] as bool? ?? true;

    // Database settings
    dbPath = database?['path'] as String? ?? 'data/shadow_app.db';
    enableWal = database?['enable_wal'] as bool? ?? true;

    // Logging settings
    logFilePath = logging?['file_path'] as String? ?? 'data/logs';
    logRetentionDays = logging?['retention_days'] as int? ?? 7;
    logLevel = logging?['level'] as String? ?? 'INFO';

    // Auth settings
    jwtSecret = auth?['jwt_secret'] as String? ?? _generateRandomSecret();
    jwtExpiryHours = auth?['jwt_expiry_hours'] as int? ?? 24;

    // Email settings (Gmail)
    gmailEmail = email?['email'] as String? ?? '';
    gmailPassword = email?['password'] as String? ?? '';
  }

  /// Load defaults (used if no config file exists)
  void _loadDefaults() {
    serverHost = '0.0.0.0';
    serverPort = 8080;
    dbPath = 'data/shadow_app.db';
    jwtSecret = _generateRandomSecret();
    jwtExpiryHours = 24;
    logFilePath = 'data/logs';
    logRetentionDays = 7;
    logLevel = 'INFO';
    gmailEmail = '';
    gmailPassword = '';
    enableCors = true;
    enableWal = true;
  }

  void _normalizePaths() {
    dbPath = _resolvePathForPlatform(dbPath);
    logFilePath = _resolvePathForPlatform(logFilePath);
  }

  /// Resolve paths based on platform conventions
  /// macOS: Uses ~/Library/Application Support/ShadowAppBackend for application data
  /// Linux/Other: Uses relative paths from the working directory
  /// This ensures each platform follows its standard data storage conventions.
  String _resolvePathForPlatform(String inputPath) {
    if (!Platform.isMacOS) {
      return inputPath;
    }

    if (path.isAbsolute(inputPath)) {
      return inputPath;
    }

    final homeDir = Platform.environment['HOME'];
    if (homeDir == null || homeDir.isEmpty) {
      return inputPath;
    }

    final baseDir = path.join(
        homeDir, 'Library', 'Application Support', 'ShadowAppBackend');
    return path.normalize(path.join(baseDir, inputPath));
  }

  /// Generate a random secret for JWT signing
  String _generateRandomSecret() {
    return 'dev-secret-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  String toString() {
    return '''
ServerConfig:
  Server: $serverHost:$serverPort
  Database: $dbPath (WAL: $enableWal)
  JWT Secret: ${jwtSecret.substring(0, 10)}... (expires in $jwtExpiryHours hours)
  Logging: $logLevel (retention: $logRetentionDays days, path: $logFilePath)
  CORS: $enableCors
  Gmail: ${gmailEmail.isNotEmpty ? 'configured' : 'not configured'}
''';
  }
}

/// Global config instance - accessed from anywhere in the app
late ServerConfig globalConfig;
