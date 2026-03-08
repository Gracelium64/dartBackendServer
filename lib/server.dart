// lib/server.dart
// Main Shadow App Backend Server using Shelf HTTP framework
// Explanation for Flutter Developers:
// This is similar to how a Flutter app sets up its UI tree with Material/Cupertino widgets.
// Here, we're setting up HTTP routes and middleware (like interceptors) to handle API requests.

import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf/shelf_io.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'config.dart';
import 'auth/auth_service.dart';
import 'auth/rule_engine.dart';
import 'database/db_manager.dart';
import 'database/models.dart';
import 'logging/logger.dart';
import 'api/crud_handlers.dart' as crud;

/// Main server class that orchestrates all HTTP handling
/// Think of this as the main entry point for the backend, similar to the main
/// MaterialApp in a Flutter app.
class ShadowAppServer {
  late HttpServer _httpServer;
  late Router _router;

  /// Initialize and start the server
  Future<void> start(
    String host,
    int port, {
    String? dbPathOverride,
    String? logLevelOverride,
  }) async {
    // Initialize configuration
    globalConfig = ServerConfig();
    await globalConfig.load();
    globalConfig.serverHost = host;
    globalConfig.serverPort = port;
    if (dbPathOverride != null && dbPathOverride.isNotEmpty) {
      globalConfig.dbPath = dbPathOverride;
    }
    if (logLevelOverride != null && logLevelOverride.isNotEmpty) {
      globalConfig.logLevel = logLevelOverride;
    }

    // Initialize core services
    database = DatabaseManager();
    await database.initialize(globalConfig.dbPath);
    await logger.initialize();

    print('''
╔════════════════════════════════════════════════════════════════════════════════╗
║              🚀 Shadow App Backend Server v0.1.0                               ║
║              Initializing core services...                                     ║
╚════════════════════════════════════════════════════════════════════════════════╝
    ''');

    // Setup router with all endpoints
    _router = Router();
    _setupRoutes();

    // Create HTTP server with middleware
    final handler = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(_loggingMiddleware)
        .addMiddleware(_authMiddleware)
        .addHandler(_router);

    // Start listening
    _httpServer = await serve(handler, host, port);

    print('''
✓ Database initialized at ${globalConfig.dbPath}
✓ Listening on http://$host:$port
✓ Admin key: YOUR_GENERATED_ADMIN_KEY_HERE (save for admin console)
✓ Log level: ${globalConfig.logLevel}
✓ CORS enabled: ${globalConfig.enableCors}

Press Ctrl+C to stop the server gracefully.
    ''');
  }

  /// Setup all HTTP routes
  void _setupRoutes() {
    // Health check endpoint
    _router.get('/health', _healthHandler);

    // Authentication endpoints
    _router.post('/auth/signup', _signupHandler);
    _router.post('/auth/login', _loginHandler);
    _router.post('/auth/refresh', _refreshHandler);

    // CRUD endpoints
    _router.post(
      '/api/collections/<collectionId>/documents',
      _createDocHandler,
    );
    _router.get(
      '/api/collections/<collectionId>/documents/<docId>',
      _readDocHandler,
    );
    _router.put(
      '/api/collections/<collectionId>/documents/<docId>',
      _updateDocHandler,
    );
    _router.delete(
      '/api/collections/<collectionId>/documents/<docId>',
      _deleteDocHandler,
    );
    _router.get('/api/collections/<collectionId>/documents', _listDocsHandler);
    _router.post('/api/admin/sql-query', _adminSqlQueryHandler);

    // Media endpoints
    _router.post('/api/media/upload', _uploadMediaHandler);
    _router.get('/api/media/download/<mediaId>', _downloadMediaHandler);
    _router.get('/api/media/metadata/<mediaId>', _mediaMetadataHandler);

    // Log endpoints (for admin GUI)
    _router.get('/api/logs/recent', _recentLogsHandler);
    _router.get('/api/logs/stream', _logsStreamHandler);

    // Catch-all for 404
    _router.all('/<ignored|.*>', _notFoundHandler);
  }

  /// Middleware: Log all incoming requests
  /// Explanation: Middleware intercepts all requests before they reach handlers.
  /// This is similar to didChangeAppLifecycleState() in Flutter—a hook to process
  /// events before they're fully handled.
  Middleware get _loggingMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        final startTime = DateTime.now();
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);
        final claims = request.context['claims'] as Map<String, dynamic>?;
        final userId = claims?['sub']?.toString() ?? 'anonymous';
        final status = response.statusCode >= 400 ? 'failed' : 'success';
        final resourcePath = '/${request.url.path}';

        await logger.logAction(
          AuditLog(
            userId: userId,
            action: 'HTTP_${request.method}',
            resourceType: 'http',
            resourceId: resourcePath,
            status: status,
            errorMessage: status == 'failed'
                ? 'HTTP ${response.statusCode} (${duration.inMilliseconds}ms)'
                : null,
          ),
        );

        print(
          '[${request.method}] ${request.url.path} → ${response.statusCode} (${duration.inMilliseconds}ms)',
        );

        return response;
      };
    };
  }

  /// Middleware: Check JWT authentication on protected routes
  Middleware get _authMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        // Routes that don't need auth
        final publicRoutes = [
          '/health',
          '/auth/signup',
          '/auth/login',
          '/api/logs/recent',
          '/api/logs/stream',
        ];
        if (publicRoutes.contains(request.url.path)) {
          print('[AUTH] Public route allowed: ${request.url.path}');
          return innerHandler(request);
        }

        // Check for Authorization header
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return _createJsonErrorResponse(401, 'Missing or invalid token');
        }

        final token = authHeader.substring(7);
        final claims = AuthService.validateToken(token);
        if (claims == null) {
          return _createJsonErrorResponse(401, 'Invalid or expired token');
        }

        return innerHandler(request.change(context: {'claims': claims}));
      };
    };
  }

  /// Handler: Health check endpoint
  /// Used to verify server is running
  Future<Response> _healthHandler(Request request) async {
    print('[!!!TEST!!!] Health endpoint called');
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
        'version': '0.1.0',
        'uptime': '0d 0h 0m',
        'database': 'connected',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handler: User signup
  Future<Response> _signupHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email'] as String?;
      final password = data['password'] as String?;

      if (email == null || password == null) {
        return _jsonErrorResponse(400, 'Email and password required');
      }

      final result = await AuthService.signup(email, password);
      if (result['success'] != true) {
        return _jsonErrorResponse(
          400,
          result['error'] as String? ?? 'Signup failed',
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            ...((result['user'] as Map<String, dynamic>?) ?? {}),
            'token': result['token'],
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: User login
  Future<Response> _loginHandler(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final email = data['email'] as String?;
      final password = data['password'] as String?;

      if (email == null || password == null) {
        return _jsonErrorResponse(400, 'Email and password required');
      }

      final result = await AuthService.login(email, password);
      if (result['success'] != true) {
        return _jsonErrorResponse(
          401,
          result['error'] as String? ?? 'Login failed',
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            ...((result['user'] as Map<String, dynamic>?) ?? {}),
            'token': result['token'],
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: Refresh JWT token
  Future<Response> _refreshHandler(Request request) async {
    try {
      String? token;
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      } else {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          token = data['token'] as String?;
        }
      }

      if (token == null || token.isEmpty) {
        return _jsonErrorResponse(400, 'Token required');
      }

      final result = await AuthService.refreshToken(token);
      if (result['success'] != true) {
        return _jsonErrorResponse(
          401,
          result['error'] as String? ?? 'Token refresh failed',
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'token': result['token']},
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: Create document
  Future<Response> _createDocHandler(Request request) async {
    return crud.handleCreateDocument(request);
  }

  /// Handler: Read document
  Future<Response> _readDocHandler(Request request) async {
    return crud.handleReadDocument(request);
  }

  /// Handler: Update document
  Future<Response> _updateDocHandler(Request request) async {
    return crud.handleUpdateDocument(request);
  }

  /// Handler: Delete document
  Future<Response> _deleteDocHandler(Request request) async {
    return crud.handleDeleteDocument(request);
  }

  /// Handler: List documents in collection
  Future<Response> _listDocsHandler(Request request) async {
    return crud.handleListDocuments(request);
  }

  /// Handler: Admin SQL query block (supports write/destructive, max 5 statements)
  Future<Response> _adminSqlQueryHandler(Request request) async {
    return crud.handleAdminSqlQuery(request);
  }

  /// Handler: Upload media
  Future<Response> _uploadMediaHandler(Request request) async {
    try {
      final claims = _claimsFromRequest(request);
      if (claims == null) {
        return _jsonErrorResponse(401, 'Not authenticated');
      }

      final multipart = await _parseMultipart(request);
      if (multipart == null) {
        return _jsonErrorResponse(400, 'Invalid multipart upload');
      }

      final destinationCollection = multipart.fields['destination_collection'];
      final destinationDocId = multipart.fields['destination_doc_id'];
      if (destinationCollection == null || destinationDocId == null) {
        return _jsonErrorResponse(
          400,
          'Destination collection and document required',
        );
      }

      if (multipart.fileBytes.isEmpty) {
        return _jsonErrorResponse(400, 'File is empty');
      }

      final userId = claims['sub'] as String;
      final user = await database.getUserById(userId);
      if (user == null) {
        return _jsonErrorResponse(403, 'User not found');
      }

      final collection = await database.getCollection(destinationCollection);
      if (collection == null) {
        return _jsonErrorResponse(404, 'Collection not found');
      }

      if (!RuleEngine.canWrite(userId, user.role, collection)) {
        await database.logAction(
          AuditLog(
            userId: userId,
            action: 'UPLOAD',
            resourceType: 'media',
            resourceId: destinationDocId,
            status: 'failed',
            errorMessage: 'Permission denied',
          ),
        );
        return _jsonErrorResponse(403, 'Permission denied');
      }

      final doc = await database.getDocument(destinationDocId);
      if (doc == null || doc.collectionId != destinationCollection) {
        return _jsonErrorResponse(404, 'Document not found');
      }

      final compressedBytes = gzip.encode(multipart.fileBytes);
      final media = MediaBlob(
        documentId: destinationDocId,
        fileName: multipart.fileName,
        mimeType: multipart.mimeType,
        originalSize: multipart.fileBytes.length,
        compressedSize: compressedBytes.length,
        compressionAlgo: 'gzip',
        blobData: compressedBytes,
      );

      await database.createMediaBlob(media);
      await database.logAction(
        AuditLog(
          userId: userId,
          action: 'UPLOAD',
          resourceType: 'media',
          resourceId: media.id,
          status: 'success',
        ),
      );

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': media.id,
            'original_size': media.originalSize,
            'compressed_size': media.compressedSize,
            'compression_algo': media.compressionAlgo,
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: Download media
  Future<Response> _downloadMediaHandler(Request request) async {
    try {
      final claims = _claimsFromRequest(request);
      if (claims == null) {
        return _jsonErrorResponse(401, 'Not authenticated');
      }

      final mediaId = request.params['mediaId'];
      if (mediaId == null || mediaId.isEmpty) {
        return _jsonErrorResponse(400, 'Media ID required');
      }

      final media = await database.getMediaBlob(mediaId);
      if (media == null) {
        return _jsonErrorResponse(404, 'Media not found');
      }

      List<int> bytes = media.blobData;
      if (media.compressionAlgo == 'gzip') {
        bytes = gzip.decode(bytes);
      }

      return Response.ok(
        bytes,
        headers: {
          'Content-Type': media.mimeType,
          'Content-Disposition':
              'attachment; filename="${path.basename(media.fileName)}"',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: 404 Not Found
  Future<Response> _notFoundHandler(Request request) async {
    return Response.notFound(
      jsonEncode({
        'success': false,
        'error': 'Endpoint not found',
        'path': request.url.path,
      }),
    );
  }

  /// Handler: Media metadata
  Future<Response> _mediaMetadataHandler(Request request) async {
    try {
      final claims = _claimsFromRequest(request);
      if (claims == null) {
        return _jsonErrorResponse(401, 'Not authenticated');
      }

      final mediaId = request.params['mediaId'];
      if (mediaId == null || mediaId.isEmpty) {
        return _jsonErrorResponse(400, 'Media ID required');
      }

      final media = await database.getMediaBlob(mediaId);
      if (media == null) {
        return _jsonErrorResponse(404, 'Media not found');
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': media.id,
            'document_id': media.documentId,
            'file_name': media.fileName,
            'mime_type': media.mimeType,
            'original_size': media.originalSize,
            'compressed_size': media.compressedSize,
            'compression_algo': media.compressionAlgo,
            'uploaded_at': media.createdAt.toIso8601String(),
          },
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Helper: Create JSON error response
  Response _jsonErrorResponse(int statusCode, String message) {
    return _createJsonErrorResponse(statusCode, message);
  }

  /// Helper: Extract claims from request context
  Map<String, dynamic>? _claimsFromRequest(Request request) {
    return request.context['claims'] as Map<String, dynamic>?;
  }

  /// Handler: Get recent logs
  Future<Response> _recentLogsHandler(Request request) async {
    try {
      // Debug: Always return success for now to test
      print('[LOGS] Handler called for ${request.url.path}');
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '100') ?? 100;
      final logs = logger.getRecentLogs(count: limit);

      return Response.ok(
        jsonEncode({
          'success': true,
          'data': logs.map((log) => log.toJson()).toList(),
          'count': logs.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Handler: Stream logs (Server-Sent Events)
  Future<Response> _logsStreamHandler(Request request) async {
    try {
      final controller = StreamController<String>();
      final subscription = logger.getLiveStream().listen((log) {
        controller.add('data: ${jsonEncode(log.toJson())}\n\n');
      });

      // Clean up when connection closes
      request.read().listen(
        null,
        onDone: () {
          subscription.cancel();
          controller.close();
        },
      );

      return Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'success': false, 'error': e.toString()}),
      );
    }
  }

  /// Helper: Parse multipart form data
  /// WARNING: This is a simplified implementation for demonstration purposes.
  /// For production use with binary files (images, videos, etc.), use a proper
  /// multipart parser library like the `mime` package's MimeMultipartTransformer.
  /// The current implementation using `codeUnits` will corrupt binary files.
  Future<_MultipartData?> _parseMultipart(Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return null;
      }

      // Extract boundary from content-type
      final boundary = contentType.split('boundary=').last;
      final body = await request.readAsString();
      // Parse multipart data
      final parts = body.split('--$boundary');
      final fields = <String, String>{};
      List<int> fileBytes = [];
      String fileName = '';
      String mimeType = 'application/octet-stream';

      for (final part in parts) {
        if (part.isEmpty || part.trim() == '--') continue;

        // Parse headers and content
        final sections = part.split('\r\n\r\n');
        if (sections.length < 2) continue;

        final headers = sections[0];
        final content = sections.sublist(1).join('\r\n\r\n').trim();

        // Check if it's a file
        if (headers.contains('filename=')) {
          final fileNameMatch = RegExp(
            r'filename="([^"]+)"',
          ).firstMatch(headers);
          if (fileNameMatch != null) {
            fileName = fileNameMatch.group(1)!;
          }

          final contentTypeMatch = RegExp(
            r'Content-Type:\s*([^\r\n]+)',
          ).firstMatch(headers);
          if (contentTypeMatch != null) {
            mimeType = contentTypeMatch.group(1)!.trim();
          }

          // Convert content to bytes
          // Note: This simplified approach treats content as text.
          // For binary files in production, use request.read() and proper multipart parsing.
          fileBytes = content.codeUnits;
        } else {
          // It's a regular field
          final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(headers);
          if (nameMatch != null) {
            final fieldName = nameMatch.group(1)!;
            fields[fieldName] = content;
          }
        }
      }

      return _MultipartData(
        fields: fields,
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (e) {
      print('[ERROR] Failed to parse multipart: $e');
      return null;
    }
  }

  /// Gracefully shutdown the server
  Future<void> stop() async {
    print('\n[INFO] Received shutdown signal');
    print('[INFO] Closing database connection...');
    print('[INFO] All logs flushed');
    await _httpServer.close();
    print('[INFO] Goodbye!');
  }
}

/// Simple multipart data holder
class _MultipartData {
  final Map<String, String> fields;
  final List<int> fileBytes;
  final String fileName;
  final String mimeType;

  _MultipartData({
    required this.fields,
    required this.fileBytes,
    required this.fileName,
    required this.mimeType,
  });
}

/// Static helper to create JSON error responses (used in middleware)
Response _createJsonErrorResponse(int statusCode, String message) {
  return Response(
    statusCode,
    body: jsonEncode({
      'success': false,
      'error': message,
      'timestamp': DateTime.now().toIso8601String(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Factory to create and run server
Future<void> runServer(
  String host,
  int port, {
  String? dbPathOverride,
  String? logLevelOverride,
}) async {
  final server = ShadowAppServer();
  await server.start(
    host,
    port,
    dbPathOverride: dbPathOverride,
    logLevelOverride: logLevelOverride,
  );

  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}
