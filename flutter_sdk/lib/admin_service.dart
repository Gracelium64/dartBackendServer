// flutter_sdk/lib/admin_service.dart
// Admin SQL service for Flutter SDK.
// Exposes admin-only SQL execution for advanced operations and maintenance.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'shadow_app.dart';

class AdminSqlStatementResult {
  final int statementIndex;
  final String statementType;
  final int rowCount;
  final bool rowCapApplied;
  final List<Map<String, dynamic>> rows;

  AdminSqlStatementResult({
    required this.statementIndex,
    required this.statementType,
    required this.rowCount,
    required this.rowCapApplied,
    required this.rows,
  });

  factory AdminSqlStatementResult.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    return AdminSqlStatementResult(
      statementIndex: (json['statement_index'] as num?)?.toInt() ?? 0,
      statementType: json['statement_type'] as String? ?? 'unknown',
      rowCount: (json['row_count'] as num?)?.toInt() ?? rows.length,
      rowCapApplied: json['row_cap_applied'] == true,
      rows: rows,
    );
  }
}

class AdminSqlResponse {
  final List<AdminSqlStatementResult> statements;
  final int statementCount;
  final int totalRows;
  final int? maxRows;
  final bool disableRowCap;

  AdminSqlResponse({
    required this.statements,
    required this.statementCount,
    required this.totalRows,
    required this.maxRows,
    required this.disableRowCap,
  });

  factory AdminSqlResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) =>
            AdminSqlStatementResult.fromJson(Map<String, dynamic>.from(entry)))
        .toList();

    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return AdminSqlResponse(
      statements: data,
      statementCount: (meta['statement_count'] as num?)?.toInt() ?? data.length,
      totalRows: (meta['total_rows'] as num?)?.toInt() ?? 0,
      maxRows: (meta['max_rows'] as num?)?.toInt(),
      disableRowCap: meta['disable_row_cap'] == true,
    );
  }
}

class AdminSqlService {
  final String serverUrl;
  final SharedPreferences prefs;

  int? _sessionMaxRows;
  bool _sessionDisableRowCap = false;

  AdminSqlService({
    required this.serverUrl,
    required this.prefs,
  });

  void setSessionRowCap(int maxRows) {
    if (maxRows <= 0) {
      throw ValidationException(
        message: 'Row cap must be a positive integer',
        originalError: maxRows,
      );
    }
    _sessionMaxRows = maxRows;
    _sessionDisableRowCap = false;
  }

  void disableSessionRowCap() {
    _sessionDisableRowCap = true;
    _sessionMaxRows = null;
  }

  void resetSessionRowCapToDefault() {
    _sessionDisableRowCap = false;
    _sessionMaxRows = null;
  }

  Future<AdminSqlResponse> execute(
    String sql, {
    List<Object?> params = const [],
    int? maxRowsOverride,
    bool disableRowCapOverride = false,
  }) async {
    final token = prefs.getString('shadow_app_token');
    if (token == null || token.isEmpty) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    if (sql.trim().isEmpty) {
      throw ValidationException(
        message: 'SQL cannot be empty',
        originalError: sql,
      );
    }

    if (maxRowsOverride != null && maxRowsOverride <= 0) {
      throw ValidationException(
        message: 'maxRowsOverride must be > 0',
        originalError: maxRowsOverride,
      );
    }

    final disableRowCap = disableRowCapOverride || _sessionDisableRowCap;
    final maxRows = disableRowCap ? null : (maxRowsOverride ?? _sessionMaxRows);

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/api/admin/sql-query'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'sql': sql,
              'params': params,
              'max_rows': maxRows,
              'disable_row_cap': disableRowCap,
            }),
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      final payload = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || payload['success'] != true) {
        throw ShadowAppException(
          message: payload['error'] as String? ?? 'Admin SQL execution failed',
          originalError: payload,
        );
      }

      return AdminSqlResponse.fromJson(payload);
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Admin SQL request failed: $e',
        originalError: e,
      );
    }
  }
}
