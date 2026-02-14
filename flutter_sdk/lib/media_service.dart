// flutter_sdk/lib/media_service.dart
// Media service for Flutter SDK - upload/download with compression
// For Flutter Developers: Handles image/video uploads with automatic compression.

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'shadow_app.dart';


/// Media upload result
class MediaUploadResult {
  final String id;
  final int originalSize;
  final int compressedSize;
  final String compressionAlgo;

  MediaUploadResult({
    required this.id,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionAlgo,
  });

  /// Get compression ratio as percentage
  double get compressionRatio => (compressedSize / originalSize * 100);

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      id: json['id'] as String,
      originalSize: json['original_size'] as int,
      compressedSize: json['compressed_size'] as int,
      compressionAlgo: json['compression_algo'] as String,
    );
  }
}

/// Media metadata
class MediaMetadata {
  final String id;
  final String fileName;
  final String mimeType;
  final int originalSize;
  final int compressedSize;
  final String compressionAlgo;
  final DateTime createdAt;

  MediaMetadata({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionAlgo,
    required this.createdAt,
  });

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      originalSize: json['original_size'] as int,
      compressedSize: json['compressed_size'] as int,
      compressionAlgo: json['compression_algo'] as String,
      createdAt: DateTime.parse(json['created_at'] as String? ?? ''),
    );
  }
}

/// Media service
class MediaService {
  final String serverUrl;
  final SharedPreferences prefs;

  MediaService({
    required this.serverUrl,
    required this.prefs,
  });

  /// Get stored auth token
  String? _getToken() {
    return prefs.getString('shadow_app_token');
  }

  /// Upload media (image, video, file)
  /// 
  /// Example:
  /// ```dart
  /// final file = File('/path/to/image.jpg');
  /// final bytes = await file.readAsBytes();
  /// 
  /// final result = await ShadowApp.media.upload(
  ///   fileBytes: bytes,
  ///   fileName: 'my_image.jpg',
  ///   mimeType: 'image/jpeg',
  ///   destinationCollection: 'photos',
  ///   destinationDocId: 'doc-123',
  /// );
  /// 
  /// print('Uploaded: ${result.id}');
  /// print('Compression: ${result.compressionRatio.toStringAsFixed(1)}%');
  /// ```
  Future<MediaUploadResult> upload({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    required String destinationCollection,
    required String destinationDocId,
  }) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    if (fileBytes.isEmpty) {
      throw ValidationException(
        message: 'File is empty',
        originalError: null,
      );
    }

    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/api/media/upload'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['destination_collection'] = destinationCollection
        ..fields['destination_doc_id'] = destinationDocId
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName,
          ),
        );

      final streamedResponse = await request.send().timeout(
            Duration(seconds: ShadowAppConfig.networkTimeout * 2), // Longer for uploads
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        throw AuthException(
          message: 'Authentication failed',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Upload failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw ShadowAppException(
          message: data['error'] ?? 'Upload failed',
          originalError: data,
        );
      }

      final result = MediaUploadResult.fromJson(data['data']);

      if (ShadowAppConfig.enableDebugLogging) {
        print('[MEDIA] Uploaded: ${result.id}');
        print('[MEDIA] Compression: ${result.compressionRatio.toStringAsFixed(1)}%');
      }

      return result;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Upload failed: $e',
        originalError: e,
      );
    }
  }

  /// Download media by ID
  /// 
  /// Example:
  /// ```dart
  /// final bytes = await ShadowApp.media.download('media-123');
  /// 
  /// // Save to file
  /// final appDir = await getApplicationDocumentsDirectory();
  /// final file = File('${appDir.path}/downloaded_image.jpg');
  /// await file.writeAsBytes(bytes);
  /// ```
  Future<Uint8List> download(String mediaId) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/api/media/download/$mediaId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout * 2));

      if (response.statusCode == 404) {
        throw ShadowAppException(
          message: 'Media not found',
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
        throw ShadowAppException(
          message: 'Download failed',
          originalError: response.body,
        );
      }

      if (ShadowAppConfig.enableDebugLogging) {
        print('[MEDIA] Downloaded: $mediaId (${response.bodyBytes.length} bytes)');
      }

      return response.bodyBytes;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Download failed: $e',
        originalError: e,
      );
    }
  }

  /// Get media metadata
  /// 
  /// Example:
  /// ```dart
  /// final metadata = await ShadowApp.media.getMetadata('media-123');
  /// print('Original: ${metadata.originalSize} bytes');
  /// print('Compressed: ${metadata.compressedSize} bytes');
  /// ```
  Future<MediaMetadata> getMetadata(String mediaId) async {
    final token = _getToken();
    if (token == null) {
      throw AuthException(
        message: 'Not authenticated',
        originalError: null,
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/api/media/metadata/$mediaId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode == 404) {
        throw ShadowAppException(
          message: 'Media not found',
          originalError: response.body,
        );
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw ShadowAppException(
          message: error['error'] ?? 'Failed to get metadata',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      return MediaMetadata.fromJson(data['data']);
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Get metadata failed: $e',
        originalError: e,
      );
    }
  }
}
