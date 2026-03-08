#!/usr/bin/env dart
//
// cli_client/bin/client.dart
// Remote command-line client for Shadow App Backend Server
//
// Usage:
//   dart bin/client.dart --server http://localhost:8080 --auth-key admin_key --list-users
//   dart bin/client.dart --server http://192.168.1.100:8080 --email user@ex.com --password pass --login
//

// ignore_for_file: unnecessary_string_escapes

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:args/args.dart';
import 'package:http/http.dart' as http;

class ShadowAppClient {
  final String serverUrl;
  String? _token;
  String? _adminKey;

  ShadowAppClient(this.serverUrl);

  /// Set authentication token
  void setToken(String token) => _token = token;

  /// Set admin key (for admin operations without login)
  void setAdminKey(String key) => _adminKey = key;

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
                Duration(seconds: 10),
              );
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(seconds: 10));
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(seconds: 10));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(Duration(seconds: 10));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on TimeoutException catch (_) {
      print('❌ Request timeout: Server did not respond within 10 seconds');
      exit(1);
    } on SocketException catch (e) {
      print('❌ Connection error: ${e.message}');
      print('   Make sure the server is running at: $serverUrl');
      exit(1);
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
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

  /// List all users
  Future<void> listUsers() async {
    try {
      final response = await request('GET', '/api/users');
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final users = (payload['data'] as List?) ?? const [];
        print('\n📋 Users (${users.length}):');
        for (final user in users) {
          print(
              '  - ${user['email']} (${user['id'].substring(0, 8)}) [${user['role']}]');
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
          print(
              '  - ${col['name']} (${col['id'].substring(0, 8)}) owner: ${col['owner_id'].substring(0, 8)}');
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
        for (final doc in docs) {
          print(
              '  - ${doc['id'].substring(0, 8)} owner: ${doc['owner_id'].substring(0, 8)}');
          print('    data: ${jsonEncode(doc['data'])}');
        }
      } else {
        print(
            '❌ Failed to list documents (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Create a collection
  Future<void> createCollection(String name) async {
    try {
      final response = await request('POST', '/api/collections', body: {
        'name': name,
      });

      if (response.statusCode == 201) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final col = payload['data'] as Map<String, dynamic>;
        print('✓ Collection created: $name (ID: ${col['id'].substring(0, 8)})');
      } else {
        print('❌ Failed to create collection: ${response.body}');
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

      if (response.statusCode == 201) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final doc = payload['data'] as Map<String, dynamic>;
        print('✓ Document created (ID: ${doc['id'].substring(0, 8)})');
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
        final logs = jsonDecode(response.body) as List;
        print('\n📊 Recent Audit Logs (${logs.length}):');
        for (final log in logs) {
          print(
            '  ${log['timestamp']} | ${log['user_id'].substring(0, 8)} | ${log['action']} | ${log['resource_type']}:${log['resource_id'].substring(0, 8)} | ${log['status']} | ${log['details'] ?? '-'}',
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
    try {
      final response = await request('POST', '/api/admin/sql-query', body: {
        'sql': sql,
        'params': params,
        'max_rows': maxRows,
        'disable_row_cap': disableRowCap,
      });

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
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
      } else {
        print('❌ SQL query failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('❌ SQL query error: $e');
    }
  }

  /// Check server health
  Future<void> checkHealth() async {
    try {
      final response = await request('GET', '/health');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✓ Server is healthy');
        print('  Status: ${data['status']}');
        if (data['timestamp'] != null) {
          print('  Timestamp: ${data['timestamp']}');
        }
      } else {
        print('❌ Server returned: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Server is not responding: $e');
    }
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

Authentication (needed for most operations):
  dart bin/client.dart --server http://localhost:8080 --email user@example.com --password mypass --login
  
  After login, the token is used for subsequent commands.

With admin key (for admin-only operations):
  dart bin/client.dart --server http://localhost:8080 --admin-key secret_key [command]

Listing data:
  dart bin/client.dart --server http://localhost:8080 --list-users
  dart bin/client.dart --server http://localhost:8080 --list-collections
  dart bin/client.dart --server http://localhost:8080 --list-documents <collection_id>

CRUD Operations:
  dart bin/client.dart --server http://localhost:8080 --create-collection <name>
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
      'login',
      help: 'Login with email and password',
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

  final client = ShadowAppClient(serverUrl);

  // Set admin key if provided
  if (results['admin-key'] != null) {
    client.setAdminKey(results['admin-key'] as String);
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
