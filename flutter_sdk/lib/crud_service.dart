// flutter_sdk/lib/crud_service.dart
// CRUD service for Flutter SDK
// For Flutter Developers: This provides intuitive methods for document operations.

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'shadow_app.dart';

/// Represents a document in a collection
class ShadowDocument {
  final String id;
  final String collectionId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShadowDocument({
    required this.id,
    required this.collectionId,
    required this.data,
    required this.createdAt,
    this.updatedAt,
  });

  factory ShadowDocument.fromJson(Map<String, dynamic> json) {
    return ShadowDocument(
      id: json['id'] as String,
      collectionId: json['collection_id'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String? ?? ''),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

/// CRUD service for a specific collection
class CrudService {
  final String collectionId;
  final String serverUrl;
  final SharedPreferences prefs;

  CrudService({
    required this.collectionId,
    required this.serverUrl,
    required this.prefs,
  });

  /// Get stored auth token
  String? _getToken() {
    return prefs.getString('shadow_app_token');
  }

  /// Create a new document
  ///
  /// Example:
  /// ```dart
  /// final doc = await ShadowApp.collection('notes').create({
  ///   'title': 'My Note',
  ///   'text': 'Hello world',
  ///   'tags': ['flutter', 'learning']
  /// });
  /// ```
  Future<ShadowDocument> create(Map<String, dynamic> data) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/api/collections/$collectionId/documents'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Create failed',
          originalError: response.body,
        );
      }

      final responseData = jsonDecode(response.body);
      if (responseData['success'] != true) {
        throw ShadowAppException(
          message: responseData['error'] ?? 'Create failed',
          originalError: responseData,
        );
      }

      if (ShadowAppConfig.enableDebugLogging) {
        print('[CRUD] Created document: ${responseData['data']['id']}');
      }

      return ShadowDocument.fromJson(responseData['data']);
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Create failed: $e',
        originalError: e,
      );
    }
  }

  /// Read a document by ID
  ///
  /// Example:
  /// ```dart
  /// final doc = await ShadowApp.collection('notes').read('doc-123');
  /// print(doc.data['title']); // "My Note"
  /// ```
  Future<ShadowDocument> read(String docId) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/collections/$collectionId/documents/$docId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 404) {
        throw ShadowAppException(
          message: 'Document not found',
          originalError: response.body,
        );
      }

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Read failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw ShadowAppException(
          message: data['error'] ?? 'Read failed',
          originalError: data,
        );
      }

      if (ShadowAppConfig.enableDebugLogging) {
        print('[CRUD] Read document: $docId');
      }

      return ShadowDocument.fromJson(data['data']);
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Read failed: $e',
        originalError: e,
      );
    }
  }

  /// List documents in the collection
  ///
  /// Example:
  /// ```dart
  /// final docs = await ShadowApp.collection('notes').list(limit: 20, offset: 0);
  /// for (final doc in docs) {
  ///   print(doc.data['title']);
  /// }
  /// ```
  Future<List<ShadowDocument>> list({
    int limit = 10,
    int offset = 0,
  }) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final url = Uri.parse(
        '$serverUrl/api/collections/$collectionId/documents'
        '?limit=$limit&offset=$offset',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'List failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw ShadowAppException(
          message: data['error'] ?? 'List failed',
          originalError: data,
        );
      }

      final docs = (data['data'] as List)
          .map((d) => ShadowDocument.fromJson(d as Map<String, dynamic>))
          .toList();

      if (ShadowAppConfig.enableDebugLogging) {
        print('[CRUD] Listed ${docs.length} documents from collection');
      }

      return docs;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'List failed: $e',
        originalError: e,
      );
    }
  }

  /// Update a document
  ///
  /// Example:
  /// ```dart
  /// await ShadowApp.collection('notes').update('doc-123', {
  ///   'text': 'Updated text',
  /// }, merge: true); // merge: true keeps other fields
  /// ```
  Future<ShadowDocument> update(
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final url = Uri.parse(
        '$serverUrl/api/collections/$collectionId/documents/$docId'
        '?merge=$merge',
      );

      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 404) {
        throw ShadowAppException(
          message: 'Document not found',
          originalError: response.body,
        );
      }

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Update failed',
          originalError: response.body,
        );
      }

      final responseData = jsonDecode(response.body);
      if (responseData['success'] != true) {
        throw ShadowAppException(
          message: responseData['error'] ?? 'Update failed',
          originalError: responseData,
        );
      }

      if (ShadowAppConfig.enableDebugLogging) {
        print('[CRUD] Updated document: $docId');
      }

      return ShadowDocument.fromJson(responseData['data']);
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Update failed: $e',
        originalError: e,
      );
    }
  }

  /// Delete a document
  ///
  /// Example:
  /// ```dart
  /// await ShadowApp.collection('notes').delete('doc-123');
  /// ```
  Future<void> delete(String docId) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final response = await http.delete(
        Uri.parse('$serverUrl/api/collections/$collectionId/documents/$docId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 404) {
        throw ShadowAppException(
          message: 'Document not found',
          originalError: response.body,
        );
      }

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Delete failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw ShadowAppException(
          message: data['error'] ?? 'Delete failed',
          originalError: data,
        );
      }

      if (ShadowAppConfig.enableDebugLogging) {
        print('[CRUD] Deleted document: $docId');
      }
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Delete failed: $e',
        originalError: e,
      );
    }
  }
}
