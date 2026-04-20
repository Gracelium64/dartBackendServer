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
  late String adminApiKey;
  late String logFilePath;
  late int logRetentionDays;
  late String logLevel;
  late String gmailEmail;
  late String gmailPassword;
  late bool enableCors;
  late bool enableWal;

  ServerConfig() {
    _loadDefaults();
    _normalizePaths();
  }

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
    adminApiKey = auth?['admin_api_key'] as String? ??
        Platform.environment['SHADOW_ADMIN_KEY'] ??
        'change-me-admin-key';

    // Email settings (Gmail SMTP with an app password)
    gmailEmail = email?['email'] as String? ??
        Platform.environment['SHADOW_GMAIL_EMAIL'] ??
        Platform.environment['SHADOW_EMAIL_ADDRESS'] ??
        '';
    gmailPassword = email?['password'] as String? ??
        Platform.environment['SHADOW_GMAIL_PASSWORD'] ??
        Platform.environment['SHADOW_EMAIL_PASSWORD'] ??
        '';
  }

  /// Load defaults (used if no config file exists)
  void _loadDefaults() {
    serverHost = '0.0.0.0';
    serverPort = 8080;
    dbPath = 'data/shadow_app.db';
    jwtSecret = _generateRandomSecret();
    jwtExpiryHours = 24;
    adminApiKey =
        Platform.environment['SHADOW_ADMIN_KEY'] ?? 'change-me-admin-key';
    logFilePath = 'data/logs';
    logRetentionDays = 7;
    logLevel = 'INFO';
    gmailEmail = Platform.environment['SHADOW_GMAIL_EMAIL'] ??
        Platform.environment['SHADOW_EMAIL_ADDRESS'] ??
        '';
    gmailPassword = Platform.environment['SHADOW_GMAIL_PASSWORD'] ??
        Platform.environment['SHADOW_EMAIL_PASSWORD'] ??
        '';
    enableCors = true;
    enableWal = true;
  }

  void _normalizePaths() {
    dbPath = _resolvePathForPlatform(dbPath);
    logFilePath = _resolvePathForPlatform(logFilePath);
  }

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

  /// Persist the current runtime config to config.yaml in the workspace root.
  Future<void> save() async {
    final configFile = File('config.yaml');
    final yaml = '''
server:
  host: ${_yamlString(serverHost)}
  port: $serverPort
  enable_cors: $enableCors

database:
  path: ${_yamlString(dbPath)}
  enable_wal: $enableWal

logging:
  file_path: ${_yamlString(logFilePath)}
  retention_days: $logRetentionDays
  level: ${_yamlString(logLevel)}

auth:
  jwt_secret: ${_yamlString(jwtSecret)}
  jwt_expiry_hours: $jwtExpiryHours
  admin_api_key: ${_yamlString(adminApiKey)}

email:
  provider: gmail
  smtp_server: smtp.gmail.com
  smtp_port: 587
  email: ${_yamlString(gmailEmail)}
  password: ${_yamlString(gmailPassword)}
''';

    await configFile.writeAsString(yaml);
  }

  String _yamlString(String value) {
    return "'${value.replaceAll("'", "''")}'";
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
  Admin API Key: ${adminApiKey == 'change-me-admin-key' ? 'default (change this)' : 'configured'}
  Logging: $logLevel (retention: $logRetentionDays days, path: $logFilePath)
  CORS: $enableCors
  Gmail: ${gmailEmail.isNotEmpty ? 'configured' : 'not configured'}
''';
  }
}

/// Global config instance - accessed from anywhere in the app
late ServerConfig globalConfig;
