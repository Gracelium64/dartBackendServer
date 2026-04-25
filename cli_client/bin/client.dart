#!/usr/bin/env dart
//
// see cli_client/bin/basics.rtf for examples of initial usage
//
//
// cli_client/bin/client.dart
// Remote command-line client for Shadow App Backend Server
//
// Usage:
//   dart bin/client.dart --server http://localhost:8080 --auth-key admin_key --list-users
//   dart bin/client.dart --server http://192.168.1.100:8080 --email user@ex.com --password pass --login
//   export SHADOW_TOKEN="..."
//   dart bin/client.dart --server http://localhost:8080 --token "$SHADOW_TOKEN" --list-users
//

// ignore_for_file: unnecessary_string_escapes

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

const String cliClientVersion = '1.0.1';

class ShadowAppClient {
  final String serverUrl;
  final int timeoutSeconds;
  String? _token;
  String? _adminKey;

  ShadowAppClient(this.serverUrl, {this.timeoutSeconds = 30});

  /// Set authentication token
  void setToken(String token) {
    final normalized = token.trim();
    _token = normalized.isEmpty ? null : normalized;
  }

  /// Current authentication token (if available)
  String? get token => _token;

  /// Set admin key (for admin operations without login)
  void setAdminKey(String key) {
    final normalized = key.trim();
    _adminKey = normalized.isEmpty ? null : normalized;
  }

  /// Make authenticated HTTP request
  Future<http.Response> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$serverUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (_adminKey != null) {
      headers['X-Admin-Key'] = _adminKey!;
    }

    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(
                Duration(seconds: timeoutSeconds),
              );
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on TimeoutException catch (_) {
      throw Exception(
        'Request timeout: Server did not respond within $timeoutSeconds seconds',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Connection error: ${e.message}. Make sure the server is running at: $serverUrl',
      );
    } catch (e) {
      throw Exception('Request error: $e');
    }

    return response;
  }

  /// Login with email and password
  Future<bool> login(String email, String password) async {
    try {
      final response = await request('POST', '/auth/login', body: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final nestedData = data['data'];
        final token = data['token'] ??
            (nestedData is Map<String, dynamic> ? nestedData['token'] : null);

        if (token is! String || token.isEmpty) {
          print('❌ Login failed: token missing in server response');
          return false;
        }

        _token = token;
        print('✓ Logged in as $email');
        return true;
      } else {
        print('❌ Login failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  String _shortId(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return 'unknown';
    }
    return text.length <= 8 ? text : text.substring(0, 8);
  }

  bool _isSuccessResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic> && payload['success'] is bool) {
        return payload['success'] as bool;
      }
    } catch (_) {
      // Some endpoints may not return a JSON body with a success field.
    }

    return true;
  }

  /// List all users
  Future<void> listUsers() async {
    try {
      final response = await request('GET', '/api/users');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final users = (payload['data'] as List?) ?? const [];
        print('\n📋 Users (${users.length}):');
        for (final user in users) {
          print('  - ${user['email']} (${user['id']}) [${user['role']}]');
        }
      } else {
        print(
            '❌ Failed to list users (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// List all collections
  Future<void> listCollections() async {
    try {
      final response = await request('GET', '/api/collections');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final collections = (payload['data'] as List?) ?? const [];
        print('\n📁 Collections (${collections.length}):');
        for (final col in collections) {
          final id = col['id'] as String;
          final ownerId = col['owner_id'] as String;
          print(
              '  - ${col['name']} (id: $id, short: ${id.substring(0, 8)}) owner: $ownerId');
        }
      } else {
        print(
            '❌ Failed to list collections (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// List documents in a collection
  Future<void> listDocuments(String collectionId) async {
    try {
      final response =
          await request('GET', '/api/collections/$collectionId/documents');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final docs = (payload['data'] as List?) ?? const [];
        print('\n📄 Documents in collection (${docs.length}):');
        for (var i = 0; i < docs.length; i++) {
          final doc = docs[i] as Map<String, dynamic>;
          final creator =
              doc['owner_id'] ?? doc['creator'] ?? doc['created_by'];
          final data = doc['data'];
          final variables = data is Map<String, dynamic>
              ? data.keys.toList(growable: false)
              : const <String>[];

          print('  ${i + 1}. id: ${_shortId(doc['id'])}');
          print('     creator: ${_shortId(creator)}');
          print(
              '     variables: ${variables.isEmpty ? '-' : variables.join(', ')}');
          print('     data: ${jsonEncode(data)}');
        }
      } else {
        print(
            '❌ Failed to list documents (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Create a collection (optionally with rules)
  Future<void> createCollection(String name, {Map<String, dynamic>? rules}) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (rules != null) {
        body['rules'] = rules;
      }
      final response = await request('POST', '/api/collections', body: body);

      if (_isSuccessResponse(response)) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final col = payload['data'] as Map<String, dynamic>;
        print('✓ Collection created: $name (ID: ${_shortId(col['id'])})');
      } else {
        print('❌ Failed to create collection: ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Delete a collection
  Future<void> deleteCollection(String collectionId) async {
    try {
      final response =
          await request('DELETE', '/api/collections/$collectionId');

      if (_isSuccessResponse(response)) {
        print(
            '✓ Collection deleted (ID: ${_shortId(collectionId)}) and all its documents');
      } else {
        print('❌ Failed to delete collection: ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Create a document
  Future<void> createDocument(
      String collectionId, Map<String, dynamic> data) async {
    try {
      final response = await request(
          'POST', '/api/collections/$collectionId/documents',
          body: data);

      if (_isSuccessResponse(response)) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final doc = payload['data'] as Map<String, dynamic>;
        print('✓ Document created (ID: ${_shortId(doc['id'])})');
      } else {
        print('❌ Failed to create document: ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Read a document
  Future<void> readDocument(String collectionId, String documentId) async {
    try {
      final response = await request(
          'GET', '/api/collections/$collectionId/documents/$documentId');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final doc = payload['data'] as Map<String, dynamic>;
        print('\n📄 Document:');
        print('  ID: ${doc['id']}');
        print('  Collection: ${doc['collection_id']}');
        print('  Data: ${_formatJson(doc['data'])}');
        print('  Created: ${doc['created_at']}');
      } else {
        print(
            '❌ Failed to read document (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Update a document
  Future<void> updateDocument(
      String collectionId, String documentId, Map<String, dynamic> data) async {
    try {
      final response = await request(
          'PUT', '/api/collections/$collectionId/documents/$documentId',
          body: data);

      if (response.statusCode == 200) {
        print('✓ Document updated');
      } else {
        print('❌ Failed to update document: ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Delete a document
  Future<void> deleteDocument(String collectionId, String documentId) async {
    try {
      final response = await request(
          'DELETE', '/api/collections/$collectionId/documents/$documentId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✓ Document deleted');
      } else {
        print('❌ Failed to delete document: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// View audit logs
  Future<void> viewLogs({int limit = 50}) async {
    try {
      final response = await request('GET', '/api/logs/recent?limit=$limit');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final logs = (payload['data'] as List?) ?? const [];
        print('\n📊 Recent Audit Logs (${logs.length}):');
        for (final log in logs) {
          final item = log as Map<String, dynamic>;
          final userId =
              (item['user_id'] ?? item['userId'] ?? 'unknown').toString();
          final resourceId =
              (item['resource_id'] ?? item['resourceId'] ?? 'unknown')
                  .toString();
          print(
            '  ${item['timestamp']} | ${_shortId(userId)} | ${item['action']} | ${item['resource_type'] ?? item['resourceType']}:${_shortId(resourceId)} | ${item['status']} | ${item['details'] ?? '-'}',
          );
        }
      } else {
        print('❌ Failed to fetch logs: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Execute admin SQL (supports up to 5 statements, including destructive).
  Future<void> runSqlQuery(
    String sql, {
    List<Object?> params = const [],
    int? maxRows,
    bool disableRowCap = false,
  }) async {
    final payload = await executeSql(
      sql,
      params: params,
      maxRows: maxRows,
      disableRowCap: disableRowCap,
    );

    if (payload == null) {
      return;
    }

    final statementResults = (payload['data'] as List?) ?? const [];
    final meta = payload['meta'] as Map<String, dynamic>? ?? const {};

    print('\n🧠 SQL executed successfully');
    print(
        '  Statements: ${meta['statement_count'] ?? statementResults.length}');
    print('  Total rows: ${meta['total_rows'] ?? 0}');
    print(
        '  Row cap: ${meta['disable_row_cap'] == true ? 'OFF' : (meta['max_rows'] ?? 'default')}');

    for (final entry in statementResults) {
      final item = entry as Map<String, dynamic>;
      final statementIndex = item['statement_index'];
      final statementType = item['statement_type'];
      final rowCount = item['row_count'];
      final rows = (item['rows'] as List?) ?? const [];

      print(
          '  • Statement #$statementIndex [$statementType] -> $rowCount row(s)');
      for (var i = 0; i < rows.length; i++) {
        print('    [${i + 1}] ${jsonEncode(rows[i])}');
      }
    }
  }

  /// Execute admin SQL and return parsed payload on success.
  Future<Map<String, dynamic>?> executeSql(
    String sql, {
    List<Object?> params = const [],
    int? maxRows,
    bool disableRowCap = false,
    bool silent = false,
  }) async {
    try {
      final response = await request('POST', '/api/admin/sql-query', body: {
        'sql': sql,
        'params': params,
        'max_rows': maxRows,
        'disable_row_cap': disableRowCap,
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (!silent) {
          print(
              '❌ SQL query failed (${response.statusCode}): ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (!silent) {
        print('❌ SQL query error: $e');
      }
      return null;
    }
  }

  /// Create or upsert a remote user using admin SQL endpoint.
  Future<void> createOrUpdateUser({
    required String email,
    required String password,
    required String role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'user' && normalizedRole != 'admin') {
      print('❌ Invalid role. Use "user" or "admin".');
      return;
    }

    final hash = _hashPasswordLikeServer(password);
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = await executeSql(
      'SELECT id FROM users WHERE email = ? LIMIT 1',
      params: [normalizedEmail],
      maxRows: 1,
    );

    final existingStatements = (existing?['data'] as List?) ?? const [];
    final existingRows = existingStatements.isEmpty
        ? const []
        : ((existingStatements.first as Map<String, dynamic>)['rows']
                as List? ??
            const []);

    if (existingRows.isNotEmpty) {
      final payload = await executeSql(
        'UPDATE users SET password_hash = ?, role = ?, updated_at = ? WHERE email = ?',
        params: [hash, normalizedRole, now, normalizedEmail],
      );
      if (payload != null) {
        print('✓ User updated: $normalizedEmail [$normalizedRole]');
      }
      return;
    }

    final userId =
        'cli_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final payload = await executeSql(
      'INSERT INTO users (id, email, password_hash, role, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      params: [userId, normalizedEmail, hash, normalizedRole, now, now],
    );

    if (payload != null) {
      print('✓ User created: $normalizedEmail [$normalizedRole]');
    }
  }

  Future<void> updateUserRoleById(String userId, String role) async {
    final resolvedUserId = await resolveUserId(userId);
    if (resolvedUserId == null) {
      return;
    }

    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'user' && normalizedRole != 'admin') {
      print('❌ Invalid role. Use "user" or "admin".');
      return;
    }
    final payload = await executeSql(
      'UPDATE users SET role = ?, updated_at = ? WHERE id = ?',
      params: [
        normalizedRole,
        DateTime.now().millisecondsSinceEpoch,
        resolvedUserId,
      ],
    );

    if (payload != null) {
      print('✓ Updated role for user: $resolvedUserId');
    }
  }

  Future<void> updateUserEmailById(String userId, String email) async {
    final resolvedUserId = await resolveUserId(userId);
    if (resolvedUserId == null) {
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final payload = await executeSql(
      'UPDATE users SET email = ?, updated_at = ? WHERE id = ?',
      params: [
        normalizedEmail,
        DateTime.now().millisecondsSinceEpoch,
        resolvedUserId,
      ],
    );

    if (payload != null) {
      print('✓ Updated email for user: $resolvedUserId');
    }
  }

  Future<void> resetUserPasswordById(String userId, String newPassword) async {
    final resolvedUserId = await resolveUserId(userId);
    if (resolvedUserId == null) {
      return;
    }

    final hash = _hashPasswordLikeServer(newPassword);
    final payload = await executeSql(
      'UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?',
      params: [
        hash,
        DateTime.now().millisecondsSinceEpoch,
        resolvedUserId,
      ],
    );

    if (payload != null) {
      print('✓ Password reset for user: $resolvedUserId');
    }
  }

  Future<void> deleteUserById(String userId) async {
    final resolvedUserId = await resolveUserId(userId);
    if (resolvedUserId == null) {
      return;
    }

    final payload = await executeSql(
      'DELETE FROM users WHERE id = ?',
      params: [resolvedUserId],
    );
    if (payload != null) {
      print('✓ Deleted user: $resolvedUserId');
    }
  }

  /// Resolve user identifier from full ID, short ID prefix, or email.
  Future<String?> resolveUserId(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      print('❌ User identifier is required.');
      return null;
    }

    if (normalized.contains('@')) {
      final emailLookup = await executeSql(
        'SELECT id FROM users WHERE email = ? LIMIT 1',
        params: [normalized.toLowerCase()],
        maxRows: 1,
        silent: true,
      );
      final idFromEmail = _extractSingleUserId(emailLookup);
      if (idFromEmail != null) {
        return idFromEmail;
      }
      print('❌ No user found for email: $normalized');
      return null;
    }

    final exactLookup = await executeSql(
      'SELECT id FROM users WHERE id = ? LIMIT 1',
      params: [normalized],
      maxRows: 1,
      silent: true,
    );
    final exactId = _extractSingleUserId(exactLookup);
    if (exactId != null) {
      return exactId;
    }

    final prefixLookup = await executeSql(
      'SELECT id, email FROM users WHERE id LIKE ? ORDER BY created_at DESC',
      params: ['${normalized}%'],
      maxRows: 10,
      silent: true,
    );

    final rows = _extractRows(prefixLookup);
    if (rows.isEmpty) {
      print('❌ No user found for ID or prefix: $normalized');
      return null;
    }

    if (rows.length == 1) {
      final id = rows.first['id']?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
      print('❌ Could not parse user ID from lookup result.');
      return null;
    }

    print('❌ Ambiguous short ID "$normalized". Matches:');
    for (final row in rows.take(5)) {
      print('  - ${row['email']} (${row['id']})');
    }
    if (rows.length > 5) {
      print('  ...and ${rows.length - 5} more');
    }
    return null;
  }

  String? _extractSingleUserId(Map<String, dynamic>? payload) {
    final rows = _extractRows(payload);
    if (rows.isEmpty) {
      return null;
    }
    final id = rows.first['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  List<Map<String, dynamic>> _extractRows(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const [];
    }

    final statements = (payload['data'] as List?) ?? const [];
    if (statements.isEmpty) {
      return const [];
    }

    final first = statements.first;
    if (first is! Map<String, dynamic>) {
      return const [];
    }

    final rows = (first['rows'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => row.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList(growable: false);
  }

  Future<void> updateCollectionRules(
      String collectionId, String rulesJson) async {
    final payload = await executeSql(
      'UPDATE collections SET rules = ?, updated_at = ? WHERE id = ?',
      params: [
        rulesJson,
        DateTime.now().millisecondsSinceEpoch,
        collectionId.trim(),
      ],
    );
    if (payload != null) {
      print('✓ Updated rules for collection: ${_shortId(collectionId)}');
    }
  }

  Future<void> showSystemStats() async {
    final payload = await executeSql(
      'SELECT (SELECT COUNT(*) FROM users) AS users, '
      '(SELECT COUNT(*) FROM collections) AS collections, '
      '(SELECT COUNT(*) FROM documents) AS documents, '
      '(SELECT COUNT(*) FROM media_blobs) AS media_blobs, '
      '(SELECT COUNT(*) FROM audit_log) AS audit_entries',
      maxRows: 1,
    );

    if (payload == null) {
      return;
    }

    final statements = (payload['data'] as List?) ?? const [];
    if (statements.isEmpty) {
      print('ℹ️ No stats returned.');
      return;
    }

    final first = statements.first as Map<String, dynamic>;
    final rows = (first['rows'] as List?) ?? const [];
    if (rows.isEmpty) {
      print('ℹ️ No stats returned.');
      return;
    }

    final stat = rows.first as Map<String, dynamic>;
    print('\n📈 Remote System Stats');
    print('  Users: ${stat['users']}');
    print('  Collections: ${stat['collections']}');
    print('  Documents: ${stat['documents']}');
    print('  Media blobs: ${stat['media_blobs']}');
    print('  Audit log entries: ${stat['audit_entries']}');
  }

  String _hashPasswordLikeServer(String password) {
    final salt = _generateRandomSalt();
    var result = password;
    for (int i = 0; i < 100000; i++) {
      result = sha256.convert(utf8.encode(result + salt)).toString();
    }
    return '$salt\$$result';
  }

  String _generateRandomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<Map<String, dynamic>?> fetchHealth() async {
    try {
      final response = await request('GET', '/health');
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Persist a TUI action in the server audit log.
  Future<void> logTuiAction(
    String action, {
    String details = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'tui_${now}_${Random.secure().nextInt(1 << 31).toString()}';
    final safeDetails =
        details.length > 700 ? '${details.substring(0, 700)}...' : details;

    await executeSql(
      'INSERT INTO audit_log '
      '(id, user_id, action, resource_type, resource_id, status, details, timestamp) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      params: [
        id,
        'admin_console',
        action,
        'tui',
        'remote_admin_console',
        'success',
        safeDetails,
        now,
      ],
      maxRows: 1,
      disableRowCap: true,
      silent: true,
    );
  }

  /// Check server health
  Future<void> checkHealth() async {
    try {
      final data = await fetchHealth();
      if (data != null) {
        print('✓ Server is healthy');
        print('  Status: ${data['status']}');
        if (data['version'] != null) {
          print('  Version: ${data['version']}');
        }
        if (data['timestamp'] != null) {
          print('  Timestamp: ${data['timestamp']}');
        }
      } else {
        print('❌ Server health check failed');
      }
    } catch (e) {
      print('❌ Server is not responding: $e');
    }
  }
}

class RemoteAdminTui {
  final ShadowAppClient client;
  String _serverVersion = 'unknown';

  RemoteAdminTui(this.client);

  Future<void> start() async {
    await _refreshServerVersion();
    var running = true;
    while (running) {
      final choice = _selectMenuOption(
        title: 'Shadow App Remote Admin Console',
        options: const [
          'Session & Authentication',
          'User Management',
          'Collection Management',
          'Document Operations',
          'Audit Logs',
          'Admin SQL Console',
          'Rules & System Stats',
          'Health Check',
          'Exit',
        ],
        escapeIndex: 8,
      );

      switch (choice) {
        case 0:
          await _sessionMenu();
          break;
        case 1:
          await _usersMenu();
          break;
        case 2:
          await _collectionsMenu();
          break;
        case 3:
          await _documentsMenu();
          break;
        case 4:
          await _logsMenu();
          break;
        case 5:
          await _sqlMenu();
          break;
        case 6:
          await _rulesAndStatsMenu();
          break;
        case 7:
          await client.checkHealth();
          await _refreshServerVersion();
          _pause();
          break;
        case 8:
          running = false;
          break;
        default:
          _warn('Invalid option.');
      }
    }

    print('Console exited.');
  }

  Future<void> _sessionMenu() async {
    var back = false;
    while (!back) {
      final choice = _selectMenuOption(
        title: 'Session & Authentication',
        options: const [
          'Login with email/password',
          'Set bearer token manually',
          'Set admin key',
          'Show session status',
          'Clear token',
          'Back',
        ],
        escapeIndex: 5,
      );

      switch (choice) {
        case 0:
          final email = _prompt('Email');
          final password = _prompt('Password');
          final success = await client.login(email, password);
          if (success) {
            print('TOKEN: ${client.token}');
          }
          _pause();
          break;
        case 1:
          final token = _prompt('JWT token');
          client.setToken(token);
          _ok('Token set.');
          _pause();
          break;
        case 2:
          final key = _prompt('Admin key');
          client.setAdminKey(key);
          _ok('Admin key set.');
          _pause();
          break;
        case 3:
          print('Bearer token: ${client.token == null ? 'not set' : 'set'}');
          _pause();
          break;
        case 4:
          client.setToken('');
          _ok('Token cleared.');
          _pause();
          break;
        case 5:
          back = true;
          break;
        default:
          _warn('Invalid option.');
      }
    }
  }

  Future<void> _usersMenu() async {
    var back = false;
    while (!back) {
      final choice = _selectMenuOption(
        title: 'User Management',
        options: const [
          'List users',
          'Create or upsert user',
          'Change user role',
          'Change user email',
          'Reset user password',
          'Delete user',
          'Back',
        ],
        escapeIndex: 6,
      );

      switch (choice) {
        case 0:
          await client.listUsers();
          _pause();
          break;
        case 1:
          final email = _prompt('Email');
          final password = _prompt('Password');
          final role = _prompt('Role (user/admin)', defaultValue: 'user');
          await client.createOrUpdateUser(
            email: email,
            password: password,
            role: role,
          );
          _pause();
          break;
        case 2:
          final userId = _prompt('User ID / Short ID / Email');
          final role = _prompt('Role (user/admin)', defaultValue: 'user');
          await client.updateUserRoleById(userId, role);
          _pause();
          break;
        case 3:
          final userId = _prompt('User ID / Short ID / Email');
          final email = _prompt('New email');
          await client.updateUserEmailById(userId, email);
          _pause();
          break;
        case 4:
          final userId = _prompt('User ID / Short ID / Email');
          final password = _prompt('New password');
          await client.resetUserPasswordById(userId, password);
          _pause();
          break;
        case 5:
          final userId = _prompt('User ID / Short ID / Email');
          if (_confirm('Delete user ${userId.trim()}?')) {
            await client.deleteUserById(userId);
          }
          _pause();
          break;
        case 6:
          back = true;
          break;
        default:
          _warn('Invalid option.');
      }
    }
  }

  Future<void> _collectionsMenu() async {
    var back = false;
    while (!back) {
      final choice = _selectMenuOption(
        title: 'Collection Management',
        options: const [
          'List collections',
          'Create collection',
          'Delete collection',
          'Update collection rules',
          'Back',
        ],
        escapeIndex: 4,
      );

      switch (choice) {
        case 0:
          await client.listCollections();
          _pause();
          break;
        case 1:
          final name = _prompt('Collection name');
          if (_confirm('Add custom rules now?')) {
            final rules = await _interactiveRulesBuilder();
            await client.createCollection(name, rules: rules);
          } else {
            await client.createCollection(name);
          }
          _pause();
          break;
        case 2:
          final collectionId = _prompt('Collection ID');
          if (_confirm('Delete collection ${collectionId.trim()}?')) {
            await client.deleteCollection(collectionId);
          }
          _pause();
          break;
        case 3:
          final collectionId = _prompt('Collection ID');
          final method = _selectMenuOption(
            title: 'Update Rules Method',
            options: const ['Interactive builder', 'Paste JSON', 'Cancel'],
            escapeIndex: 2,
          );
          if (method == 0) {
            final rules = await _interactiveRulesBuilder();
            final rulesJson = jsonEncode(rules);
            await client.updateCollectionRules(collectionId, rulesJson);
            _pause();
            break;
          } else if (method == 1) {
            final rules = _prompt('Rules JSON');
            try {
              jsonDecode(rules);
            } catch (e) {
              _warn('Invalid JSON: $e');
              _pause();
              break;
            }
            await client.updateCollectionRules(collectionId, rules);
            _pause();
            break;
          } else {
            // Cancel or back
            break;
          }
        case 4:
          back = true;
          break;
        default:
          _warn('Invalid option.');
      }
    }
  }

  Future<void> _documentsMenu() async {
    var back = false;
    while (!back) {
      final choice = _selectMenuOption(
        title: 'Document Operations',
        options: const [
          'List documents in collection',
          'Create document',
          'Read document',
          'Update document',
          'Delete document',
          'Back',
        ],
        escapeIndex: 5,
      );

      switch (choice) {
        case 0:
          final collectionId = _prompt('Collection ID');
          await client.listDocuments(collectionId);
          _pause();
          break;
        case 1:
          final collectionId = _prompt('Collection ID');
          final dataRaw = _prompt('Document JSON payload');
          try {
            final data = jsonDecode(dataRaw) as Map<String, dynamic>;
            await client.createDocument(collectionId, data);
          } catch (e) {
            _warn('Invalid JSON payload: $e');
          }
          _pause();
          break;
        case 2:
          final collectionId = _prompt('Collection ID');
          final documentId = _prompt('Document ID');
          await client.readDocument(collectionId, documentId);
          _pause();
          break;
        case 3:
          final collectionId = _prompt('Collection ID');
          final documentId = _prompt('Document ID');
          final dataRaw = _prompt('Updated JSON payload');
          try {
            final data = jsonDecode(dataRaw) as Map<String, dynamic>;
            await client.updateDocument(collectionId, documentId, data);
          } catch (e) {
            _warn('Invalid JSON payload: $e');
          }
          _pause();
          break;
        case 4:
          final collectionId = _prompt('Collection ID');
          final documentId = _prompt('Document ID');
          if (_confirm('Delete document ${documentId.trim()}?')) {
            await client.deleteDocument(collectionId, documentId);
          }
          _pause();
          break;
        case 5:
          back = true;
          break;
        default:
          _warn('Invalid option.');
      }
    }
  }

  Future<void> _logsMenu() async {
    _clearScreen();
    _printHeader('Audit Logs');
    final rawLimit = _prompt('Limit', defaultValue: '50');
    final parsed = int.tryParse(rawLimit.trim());
    await client.viewLogs(limit: parsed == null || parsed <= 0 ? 50 : parsed);
    _pause();
  }

  Future<void> _sqlMenu() async {
    _clearScreen();
    _printHeader('Admin SQL Console');
    _printSqlConsoleCommandCatalog();
    print('');
    print('SQL Console Mode (live): no screen rerender while active.');
    print('Type :help for console commands, :back to return.');

    var maxRows = 200;
    var disableRowCap = false;

    await client.logTuiAction(
      'TUI_SQL_MODE_ENTER',
      details: 'entered admin sql console',
    );

    while (true) {
      stdout.write('sql> ');
      final raw = stdin.readLineSync();
      if (raw == null) {
        continue;
      }

      final input = raw.trim();
      if (input.isEmpty) {
        continue;
      }

      final lower = input.toLowerCase();
      if (lower == ':back' || lower == ':exit' || lower == ':quit') {
        await client.logTuiAction(
          'TUI_SQL_MODE_EXIT',
          details: 'left admin sql console',
        );
        break;
      }

      if (lower == ':help' || lower == ':commands') {
        _printSqlConsoleCommandCatalog();
        continue;
      }

      if (lower == ':examples') {
        _printSqlExamples();
        continue;
      }

      if (lower == ':cap off') {
        disableRowCap = true;
        print('ℹ️ Row cap disabled for this SQL console session.');
        continue;
      }

      if (lower == ':cap default') {
        disableRowCap = false;
        maxRows = 200;
        print('ℹ️ Row cap reset to default (200).');
        continue;
      }

      if (lower.startsWith(':cap ')) {
        final value = lower.substring(5).trim();
        final parsed = int.tryParse(value);
        if (parsed == null || parsed <= 0) {
          print('❌ Invalid cap. Use: :cap <positive_integer>');
          continue;
        }
        disableRowCap = false;
        maxRows = parsed;
        print('ℹ️ Row cap set to $maxRows for this SQL console session.');
        continue;
      }

      await client.logTuiAction(
        'TUI_SQL_EXECUTE',
        details: input,
      );
      await client.runSqlQuery(
        input,
        maxRows: disableRowCap ? null : maxRows,
        disableRowCap: disableRowCap,
      );
      print('');
    }
  }

  Future<void> _rulesAndStatsMenu() async {
    var back = false;
    while (!back) {
      final choice = _selectMenuOption(
        title: 'Rules & System Stats',
        options: const [
          'Show system stats',
          'Show recent admin actions',
          'Back',
        ],
        escapeIndex: 2,
      );

      switch (choice) {
        case 0:
          await client.showSystemStats();
          _pause();
          break;
        case 1:
          await client.runSqlQuery(
            'SELECT user_id, action, resource_type, resource_id, status, timestamp '
            'FROM audit_log ORDER BY timestamp DESC LIMIT 25',
            maxRows: 25,
          );
          _pause();
          break;
        case 2:
          back = true;
          break;
        default:
          _warn('Invalid option.');
      }
    }
  }

  /// Interactive helper to build collection rules (read/write/public_read)
  Future<Map<String, dynamic>> _interactiveRulesBuilder([
    Map<String, dynamic>? initial,
  ]) async {
    final readSet = <String>{};
    final writeSet = <String>{};
    var publicRead = false;

    if (initial != null) {
      if (initial['read'] is List) {
        readSet.addAll((initial['read'] as List).whereType<String>());
      }
      if (initial['write'] is List) {
        writeSet.addAll((initial['write'] as List).whereType<String>());
      }
      if (initial['public_read'] is bool) {
        publicRead = initial['public_read'] as bool;
      }
    } else {
      // sensible defaults
      readSet.addAll(['admin', 'owner']);
      writeSet.addAll(['admin', 'owner']);
    }

    Future<void> _editRoleSet(String title, Set<String> target) async {
      var back = false;
      final roleOptions = ['owner', 'admin', 'user', 'authenticated'];
      while (!back) {
        final display = roleOptions
            .map((r) => target.contains(r) ? '☑ $r' : '☐ $r')
            .toList();
        final opts = [...display, 'Add specific user ID', 'Remove specific user ID', 'Back'];
        final choice = _selectMenuOption(
          title: title,
          options: opts,
          escapeIndex: opts.length - 1,
        );

        if (choice < 0) return;
        if (choice < roleOptions.length) {
          final role = roleOptions[choice];
          if (target.contains(role)) {
            target.remove(role);
          } else {
            target.add(role);
          }
          continue;
        }

        final selected = choice - roleOptions.length;
        if (selected == 0) {
          final id = _prompt('User ID to allow');
          if (id.trim().isNotEmpty) target.add(id.trim());
          continue;
        }

        if (selected == 1) {
          if (target.where((s) => s != 'owner' && s != 'admin' && s != 'user' && s != 'authenticated').isEmpty) {
            _warn('No specific user IDs to remove');
            continue;
          }
          final ids = target
              .where((s) => s != 'owner' && s != 'admin' && s != 'user' && s != 'authenticated')
              .toList();
          final optsIds = [...ids, 'Back'];
          final rem = _selectMenuOption(
            title: 'Remove specific user ID',
            options: optsIds,
            escapeIndex: optsIds.length - 1,
          );
          if (rem < 0 || rem >= ids.length) continue;
          target.remove(ids[rem]);
          continue;
        }

        back = true;
      }
    }

    while (true) {
      _clearScreen();
      _printHeader('Collection Rules Builder');
      print('Public read: ${publicRead ? 'Yes' : 'No'}');
      print('Read list: ${readSet.isEmpty ? '-' : readSet.join(', ')}');
      print('Write list: ${writeSet.isEmpty ? '-' : writeSet.join(', ')}');
      print('');

      final choice = _selectMenuOption(
        title: 'Edit rules',
        options: const [
          'Toggle public_read',
          'Edit read roles',
          'Edit write roles',
          'Add specific read user ID',
          'Add specific write user ID',
          'Finish',
        ],
        escapeIndex: 5,
      );

      switch (choice) {
        case 0:
          publicRead = !publicRead;
          break;
        case 1:
          await _editRoleSet('Edit read roles', readSet);
          break;
        case 2:
          await _editRoleSet('Edit write roles', writeSet);
          break;
        case 3:
          final id = _prompt('User ID to allow read');
          if (id.trim().isNotEmpty) readSet.add(id.trim());
          break;
        case 4:
          final id = _prompt('User ID to allow write');
          if (id.trim().isNotEmpty) writeSet.add(id.trim());
          break;
        case 5:
        default:
          return {
            'read': readSet.toList(),
            'write': writeSet.toList(),
            'public_read': publicRead,
          };
      }
    }
  }

  void _printHeader(String title) {
    print('\n============================================================');
    print(title);
    print('Client v$cliClientVersion | Server v$_serverVersion');
    print('Server: ${client.serverUrl}');
    print('============================================================');
  }

  Future<void> _refreshServerVersion() async {
    final health = await client.fetchHealth();
    final version = health?['version']?.toString().trim();
    if (version != null && version.isNotEmpty) {
      _serverVersion = version;
      return;
    }
    _serverVersion = 'unavailable';
  }

  int _selectMenuOption({
    required String title,
    required List<String> options,
    String? subtitle,
    int defaultIndex = 0,
    int? escapeIndex,
  }) {
    if (options.isEmpty) {
      return -1;
    }

    if (!stdin.hasTerminal) {
      _clearScreen();
      _printHeader(title);
      if (subtitle != null && subtitle.trim().isNotEmpty) {
        print(subtitle);
      }
      for (var i = 0; i < options.length; i++) {
        print('${i + 1}. ${options[i]}');
      }
      final raw = _prompt('Select option', defaultValue: '${defaultIndex + 1}');
      final selected = int.tryParse(raw.trim());
      if (selected == null || selected < 1 || selected > options.length) {
        return defaultIndex.clamp(0, options.length - 1);
      }
      return selected - 1;
    }

    var selectedIndex = defaultIndex.clamp(0, options.length - 1);
    final previousEcho = stdin.echoMode;
    final previousLine = stdin.lineMode;

    stdin.echoMode = false;
    stdin.lineMode = false;

    try {
      while (true) {
        _clearScreen();
        _printHeader(title);
        if (subtitle != null && subtitle.trim().isNotEmpty) {
          print(subtitle);
          print('');
        }

        for (var i = 0; i < options.length; i++) {
          final marker = i == selectedIndex ? '❯' : ' ';
          print('$marker ${i + 1}. ${options[i]}');
        }

        _printMenuLegend();

        final key = stdin.readByteSync();

        if (key == 10 || key == 13) {
          _logMenuSelection(title, options[selectedIndex]);
          return selectedIndex;
        }

        if (key == 113 || key == 81) {
          if (escapeIndex != null &&
              escapeIndex >= 0 &&
              escapeIndex < options.length) {
            _logMenuSelection(title, options[escapeIndex]);
            return escapeIndex;
          }
          return defaultIndex.clamp(0, options.length - 1);
        }

        if (key >= 49 && key <= 57) {
          final index = key - 49;
          if (index >= 0 && index < options.length) {
            _logMenuSelection(title, options[index]);
            return index;
          }
        }

        if (key == 27) {
          final bracket = stdin.readByteSync();
          if (bracket == 91) {
            final arrow = stdin.readByteSync();
            if (arrow == 65) {
              selectedIndex =
                  (selectedIndex - 1 + options.length) % options.length;
            } else if (arrow == 66) {
              selectedIndex = (selectedIndex + 1) % options.length;
            } else if (arrow == 67) {
              selectedIndex = (selectedIndex + 1) % options.length;
            } else if (arrow == 68) {
              selectedIndex =
                  (selectedIndex - 1 + options.length) % options.length;
            }
          } else if (escapeIndex != null &&
              escapeIndex >= 0 &&
              escapeIndex < options.length) {
            _logMenuSelection(title, options[escapeIndex]);
            return escapeIndex;
          }
        }
      }
    } finally {
      stdin.echoMode = previousEcho;
      stdin.lineMode = previousLine;
      _clearScreen();
    }
  }

  void _clearScreen() {
    stdout.write('\x1B[2J\x1B[H');
  }

  void _printMenuLegend() {
    print('');
    print('------------------------------------------------------------');
    print('Controls: ↑/↓/←/→ move | Enter select | 1-9 quick select');
    print('          Esc/Q back');
    print('------------------------------------------------------------');
  }

  void _logMenuSelection(String title, String selectedOption) {
    unawaited(
      client.logTuiAction(
        'TUI_MENU_SELECT',
        details: '$title -> $selectedOption',
      ),
    );
  }

  void _printSqlConsoleCommandCatalog() {
    print('SQL Console Commands:');
    print('  :help / :commands   Show this command list');
    print('  :examples           Show SQL examples');
    print('  :cap <n>            Set SQL row cap for this session');
    print('  :cap off            Disable SQL row cap for this session');
    print('  :cap default        Restore default SQL row cap (200)');
    print('  :back / :exit       Leave SQL console');
    print('');
    _printSqlExamples();
  }

  void _printSqlExamples() {
    print('SQL Examples:');
    print('');
    print('  -- Quick inspection --');
    print('  SELECT id, owner_id FROM documents LIMIT 5');
    print(
        '  SELECT id, email, role FROM users ORDER BY created_at DESC LIMIT 20');
    print(
        '  SELECT id, name, owner_id FROM collections ORDER BY created_at DESC');
    print('');
    print('  -- Filtered reads --');
    print('  SELECT * FROM documents WHERE owner_id = ? LIMIT 10');
    print(
        '  SELECT * FROM audit_log WHERE action = \'TUI_SQL_EXECUTE\' ORDER BY timestamp DESC LIMIT 50');
    print('');
    print('  -- Updates --');
    print("  UPDATE users SET role='admin' WHERE email='ops@example.com'");
    print(
        "  UPDATE collections SET rules='{\"read\":[\"owner\"],\"write\":[\"owner\"],\"public_read\":false}' WHERE id='collection_id'");
    print('');
    print('  -- Multi-statement maintenance --');
    print(
      "  DELETE FROM documents WHERE owner_id='legacy_user'; SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5",
    );
    print('');
    print('  -- TUI action log tail --');
    print(
        "  SELECT user_id, action, details, timestamp FROM audit_log WHERE resource_type='tui' ORDER BY timestamp DESC LIMIT 100");
  }

  String _prompt(String label, {String defaultValue = ''}) {
    final suffix = defaultValue.isEmpty ? '' : ' [$defaultValue]';
    stdout.write('$label$suffix: ');
    final value = stdin.readLineSync()?.trim() ?? '';
    if (value.isEmpty) {
      return defaultValue;
    }
    return value;
  }

  bool _confirm(String prompt) {
    final choice = _selectMenuOption(
      title: 'Confirm',
      subtitle: prompt,
      options: const ['No', 'Yes'],
      escapeIndex: 0,
    );
    return choice == 1;
  }

  void _pause() {
    stdout.write('\nPress Enter to continue...');
    stdin.readLineSync();
  }

  void _warn(String text) {
    print('⚠ $text');
  }

  void _ok(String text) {
    print('✓ $text');
  }
}

void printUsage(ArgParser parser) {
  print('''
Shadow App CLI Client
=====================
Remote command-line interface for Shadow App Backend Server

USAGE:
  dart bin/client.dart [options] [command]

OPTIONS:
${parser.usage}

EXAMPLES:

Interactive TUI admin console:
  dart bin/client.dart --server https://shadow-app-server.onrender.com --tui
  dart bin/client.dart --server https://shadow-app-server.onrender.com --admin-key <key> --tui

Authentication (needed for most operations):
  dart bin/client.dart --server http://localhost:8080 --email user@example.com --password mypass --login
  dart bin/client.dart --server http://localhost:8080 --email user@example.com --password mypass --login --print-token
  dart bin/client.dart --server http://localhost:8080 --token "\$SHADOW_TOKEN" --list-users
  
  After login, the token is used for subsequent commands in the same run.

With admin key (for admin-only operations):
  dart bin/client.dart --server http://localhost:8080 --admin-key secret_key [command]

Listing data:
  dart bin/client.dart --server http://localhost:8080 --list-users
  dart bin/client.dart --server http://localhost:8080 --list-collections
  dart bin/client.dart --server http://localhost:8080 --list-documents <collection_id>

CRUD Operations:
  dart bin/client.dart --server http://localhost:8080 --create-collection <name>
  dart bin/client.dart --server http://localhost:8080 --delete-collection <collection_id>
  dart bin/client.dart --server http://localhost:8080 --create-document <collection_id> <json_data>
  dart bin/client.dart --server http://localhost:8080 --read-document <collection_id> <document_id>
  dart bin/client.dart --server http://localhost:8080 --update-document <collection_id> <document_id> <json_data>
  dart bin/client.dart --server http://localhost:8080 --delete-document <collection_id> <document_id>

Advanced SQL queries (admin-only, up to 5 statements):
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "SELECT id, owner_id FROM documents LIMIT 5"
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "SELECT * FROM documents WHERE owner_id = ? LIMIT 10" --sql-params "[\"user123\"]"
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "UPDATE users SET role='admin' WHERE email='ops@example.com'"
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "DELETE FROM documents WHERE owner_id='legacy_user'; SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5"

Row cap override (current client run/session):
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "SELECT * FROM documents" --sql-cap 1000
  dart bin/client.dart --server http://localhost:8080 --email admin@ex.com --password pass --login --sql "SELECT * FROM documents" --sql-cap-off

Other:
  dart bin/client.dart --server http://localhost:8080 --health
  dart bin/client.dart --server http://localhost:8080 --view-logs
''');
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'server',
      abbr: 's',
      help:
          'Server URL (e.g., http://localhost:8080 or http://192.168.1.100:8080)',
      valueHelp: 'url',
    )
    ..addOption(
      'timeout',
      help: 'HTTP request timeout in seconds (default: 30)',
      defaultsTo: '30',
      valueHelp: 'seconds',
    )
    ..addOption(
      'token',
      abbr: 't',
      help:
          'JWT token for authenticated requests (e.g., --token "\$SHADOW_TOKEN")',
      valueHelp: 'jwt_token',
    )
    ..addOption(
      'email',
      abbr: 'e',
      help: 'Email for login',
      valueHelp: 'email@example.com',
    )
    ..addOption(
      'password',
      abbr: 'p',
      help: 'Password for login',
      valueHelp: 'password',
    )
    ..addOption(
      'admin-key',
      abbr: 'a',
      help: 'Admin key for admin operations (instead of email/password)',
      valueHelp: 'key',
    )
    ..addFlag(
      'tui',
      help: 'Launch interactive remote admin TUI console',
      negatable: false,
    )
    ..addFlag(
      'login',
      help: 'Login with email and password',
    )
    ..addFlag(
      'print-token',
      help: 'Print token after a successful login (for export/reuse)',
      negatable: false,
    )
    ..addFlag(
      'health',
      help: 'Check server health status',
    )
    ..addFlag(
      'list-users',
      help: 'List all users',
    )
    ..addFlag(
      'list-collections',
      help: 'List all collections',
    )
    ..addOption(
      'list-documents',
      abbr: 'l',
      help: 'List documents in a collection',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'create-collection',
      help: 'Create a new collection',
      valueHelp: 'name',
    )
    ..addOption(
      'delete-collection',
      help: 'Delete a collection (and all its documents)',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'create-document',
      help: 'Create a document in collection (use with --data)',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'read-document',
      help: 'Read a document (use with --collection and --document-id)',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'update-document',
      help: 'Update a document (use with --document-id and --data)',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'delete-document',
      help: 'Delete a document (use with --collection and --document-id)',
      valueHelp: 'collection_id',
    )
    ..addOption(
      'document-id',
      abbr: 'd',
      help: 'Document ID (for read/update/delete operations)',
      valueHelp: 'doc_id',
    )
    ..addOption(
      'data',
      help:
          'JSON data for create/update (inline: {\'key\':\'value\'} or file: @file.json)',
      valueHelp: 'json',
    )
    ..addOption(
      'view-logs',
      help: 'View audit logs (optional: number of entries)',
      valueHelp: 'count',
    )
    ..addOption(
      'sql',
      help: 'Execute admin SQL (supports up to 5 statements)',
      valueHelp: 'query',
    )
    ..addOption(
      'sql-params',
      help: 'Optional JSON array of SQL bind parameters, e.g. ["user123",10]',
      valueHelp: 'json_array',
    )
    ..addOption(
      'sql-cap',
      help: 'Override row cap for this run/session (positive integer)',
      valueHelp: 'count',
    )
    ..addFlag(
      'sql-cap-off',
      help: 'Disable SQL row cap for this run/session',
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
    );

  late ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    print('❌ Error: $e\n');
    printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    printUsage(parser);
    exit(0);
  }

  final serverUrl = results['server'] as String?;
  if (serverUrl == null) {
    print('❌ Error: --server option is required\n');
    printUsage(parser);
    exit(1);
  }

  final timeoutSeconds = int.tryParse(results['timeout'] as String? ?? '30');
  if (timeoutSeconds == null || timeoutSeconds <= 0) {
    print('❌ Error: --timeout must be a positive integer\n');
    printUsage(parser);
    exit(1);
  }

  final client = ShadowAppClient(serverUrl, timeoutSeconds: timeoutSeconds);

  // Set admin key if provided
  if (results['admin-key'] != null) {
    client.setAdminKey(results['admin-key'] as String);
  }

  // Set bearer token for authenticated requests
  if (results['token'] != null) {
    client.setToken(results['token'] as String);
  }

  // Handle login
  if (results['login'] as bool) {
    final email = results['email'] as String?;
    final password = results['password'] as String?;
    if (email == null || password == null) {
      print('❌ Error: --email and --password are required for login\n');
      exit(1);
    }
    final success = await client.login(email, password);
    if (!success) exit(1);

    if (results['print-token'] as bool) {
      final token = client.token;
      if (token == null || token.isEmpty) {
        print('❌ Error: login succeeded but no token is available to print');
        exit(1);
      }
      print('TOKEN: $token');
    } else {
      print('ℹ️  Tip: use --print-token to output the JWT for reuse.');
    }
  }

  // Launch interactive terminal UI mode.
  if (results['tui'] as bool) {
    final tui = RemoteAdminTui(client);
    await tui.start();
    return;
  }

  // Handle commands
  if (results['health'] as bool) {
    await client.checkHealth();
  } else if (results['list-users'] as bool) {
    await client.listUsers();
  } else if (results['list-collections'] as bool) {
    await client.listCollections();
  } else if (results['list-documents'] != null) {
    await client.listDocuments(results['list-documents'] as String);
  } else if (results['create-collection'] != null) {
    await client.createCollection(results['create-collection'] as String);
  } else if (results['delete-collection'] != null) {
    await client.deleteCollection(results['delete-collection'] as String);
  } else if (results['create-document'] != null) {
    final collectionId = results['create-document'] as String;
    final dataStr = results['data'] as String?;
    if (dataStr == null) {
      print('❌ Error: --data is required for create-document');
      exit(1);
    }
    final data = _parseJsonData(dataStr);
    await client.createDocument(collectionId, data);
  } else if (results['read-document'] != null) {
    final collectionId = results['read-document'] as String;
    final documentId = results['document-id'] as String?;
    if (documentId == null) {
      print('❌ Error: --document-id is required for read-document');
      exit(1);
    }
    await client.readDocument(collectionId, documentId);
  } else if (results['update-document'] != null) {
    final collectionId = results['update-document'] as String;
    final documentId = results['document-id'] as String?;
    if (documentId == null) {
      print('❌ Error: --document-id is required for update-document');
      exit(1);
    }
    final dataStr = results['data'] as String?;
    if (dataStr == null) {
      print('❌ Error: --data is required for update-document');
      exit(1);
    }
    final data = _parseJsonData(dataStr);
    await client.updateDocument(collectionId, documentId, data);
  } else if (results['delete-document'] != null) {
    final collectionId = results['delete-document'] as String;
    final documentId = results['document-id'] as String?;
    if (documentId == null) {
      print('❌ Error: --document-id is required for delete-document');
      exit(1);
    }
    await client.deleteDocument(collectionId, documentId);
  } else if (results['view-logs'] != null) {
    final limitStr = results['view-logs'] as String?;
    final limit = limitStr != null ? int.tryParse(limitStr) ?? 50 : 50;
    await client.viewLogs(limit: limit);
  } else if (results['sql'] != null) {
    final sql = results['sql'] as String;
    final paramsRaw = results['sql-params'] as String?;
    final params = _parseSqlParams(paramsRaw);
    final capRaw = results['sql-cap'] as String?;
    final disableCap = results['sql-cap-off'] as bool;
    final cap = _parseSqlCap(capRaw);
    if (disableCap && cap != null) {
      print('❌ Error: use either --sql-cap or --sql-cap-off, not both');
      exit(1);
    }
    await client.runSqlQuery(
      sql,
      params: params,
      maxRows: cap,
      disableRowCap: disableCap,
    );
  } else {
    print('ℹ️  No command specified. Use --help for usage information.');
  }
}

int? _parseSqlCap(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed <= 0) {
    print('❌ Error: --sql-cap must be a positive integer');
    exit(1);
  }
  return parsed;
}

List<Object?> _parseSqlParams(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }

  try {
    final parsed = jsonDecode(raw);
    if (parsed is List) {
      return List<Object?>.from(parsed);
    }

    print('❌ Error: --sql-params must be a JSON array');
    exit(1);
  } catch (e) {
    print('❌ Error parsing --sql-params JSON: $e');
    exit(1);
  }
}

/// Parse JSON data from string or file
Map<String, dynamic> _parseJsonData(String dataStr) {
  try {
    // If starts with @, read from file
    if (dataStr.startsWith('@')) {
      final filePath = dataStr.substring(1);
      final file = File(filePath);
      if (!file.existsSync()) {
        print('❌ Error: File not found: $filePath');
        exit(1);
      }
      final content = file.readAsStringSync();
      return jsonDecode(content) as Map<String, dynamic>;
    }
    // Otherwise parse as JSON string
    return jsonDecode(dataStr) as Map<String, dynamic>;
  } catch (e) {
    print('❌ Error parsing JSON: $e');
    print('   Use: {\'key\':\'value\'} or @file.json');
    exit(1);
  }
}

/// Format JSON for display
String _formatJson(dynamic data, {int indent = 0}) {
  final indentStr = ' ' * indent;
  if (data is Map) {
    if (data.isEmpty) return '{}';
    final entries = data.entries
        .map((e) =>
            '$indentStr  "${e.key}": ${_formatJson(e.value, indent: indent + 2)}')
        .join(',\n');
    return '{\n$entries\n$indentStr}';
  } else if (data is List) {
    if (data.isEmpty) return '[]';
    final items =
        data.map((item) => _formatJson(item, indent: indent + 2)).join(',\n');
    return '[\n$indentStr  $items\n$indentStr]';
  } else {
    return jsonEncode(data);
  }
}
