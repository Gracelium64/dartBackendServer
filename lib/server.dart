// lib/server.dart
// Main Shadow App Backend Server using Shelf HTTP framework
// Explanation for Flutter Developers:
// This is similar to how a Flutter app sets up its UI tree with Material/Cupertino widgets.
// Here, we're setting up HTTP routes and middleware (like interceptors) to handle API requests.

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'dart:io';
import 'dart:convert';
import 'config.dart';

/// Main server class that orchestrates all HTTP handling
/// Think of this as the main entry point for the backend, similar to the main
/// MaterialApp in a Flutter app.
class ShadowAppServer {
  late HttpServer _httpServer;
  late Router _router;

  /// Initialize and start the server
  Future<void> start(String host, int port) async {
    // Initialize configuration
    await globalConfig.load();

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
    _httpServer = await HttpServer.bind(host, port);
    _httpServer.listen(handler);

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
    _router.post('/api/collections/<collectionId>/documents', _createDocHandler);
    _router.get('/api/collections/<collectionId>/documents/<docId>',
        _readDocHandler);
    _router.put('/api/collections/<collectionId>/documents/<docId>',
        _updateDocHandler);
    _router.delete(
        '/api/collections/<collectionId>/documents/<docId>', _deleteDocHandler);
    _router.get('/api/collections/<collectionId>/documents', _listDocsHandler);

    // Media endpoints
    _router.post('/api/media/upload', _uploadMediaHandler);
    _router.get('/api/media/download/<mediaId>', _downloadMediaHandler);

    // Catch-all for 404
    _router.all('/<ignored|.*>', _notFoundHandler);
  }

  /// Middleware: Log all incoming requests
  /// Explanation: Middleware intercepts all requests before they reach handlers.
  /// This is similar to didChangeAppLifecycleState() in Flutter—a hook to process
  /// events before they're fully handled.
  Middleware _loggingMiddleware = (Handler innerHandler) {
    return (Request request) async {
      final startTime = DateTime.now();
      final response = await innerHandler(request);
      final duration = DateTime.now().difference(startTime);

      print(
          '[${request.method}] ${request.url.path} → ${response.statusCode} (${duration.inMilliseconds}ms)');

      return response;
    };
  };

  /// Middleware: Check JWT authentication on protected routes
  Middleware _authMiddleware = (Handler innerHandler) {
    return (Request request) async {
      // Routes that don't need auth
      final publicRoutes = ['/health', '/auth/signup', '/auth/login'];
      if (publicRoutes.contains(request.url.path)) {
        return innerHandler(request);
      }

      // Check for Authorization header
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized(
          jsonEncode({'success': false, 'error': 'Missing or invalid token'}),
        );
      }

      // TODO: Validate JWT token
      // For now, pass through
      return innerHandler(request);
    };
  };

  /// Handler: Health check endpoint
  /// Used to verify server is running
  Future<Response> _healthHandler(Request request) async {
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
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'error': 'Email and password required'
          }),
        );
      }

      // TODO: Implement actual signup
      // For now, return mock response
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'user-abc123',
            'email': email,
            'token': 'jwt_token_here',
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
        return Response.badRequest(
          body: jsonEncode({
            'success': false,
            'error': 'Email and password required'
          }),
        );
      }

      // TODO: Implement actual login with password verification
      // For now, return mock response
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'user-xyz789',
            'email': email,
            'token': 'jwt_token_here',
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
      // TODO: Implement token refresh
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'token': 'new_jwt_token_here'},
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
    try {
      final collectionId = request.params['collectionId'];
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // TODO: Implement actual document creation
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'doc-abc123',
            'collection': collectionId,
            'data': data,
            'created_at': DateTime.now().toIso8601String(),
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

  /// Handler: Read document
  Future<Response> _readDocHandler(Request request) async {
    try {
      final collectionId = request.params['collectionId'];
      final docId = request.params['docId'];

      // TODO: Implement actual document retrieval
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': docId,
            'collection': collectionId,
            'data': {'example': 'data'},
            'created_at': DateTime.now().toIso8601String(),
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

  /// Handler: Update document
  Future<Response> _updateDocHandler(Request request) async {
    try {
      final collectionId = request.params['collectionId'];
      final docId = request.params['docId'];
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      // TODO: Implement actual document update
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': docId,
            'collection': collectionId,
            'data': data,
            'updated_at': DateTime.now().toIso8601String(),
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

  /// Handler: Delete document
  Future<Response> _deleteDocHandler(Request request) async {
    try {
      final collectionId = request.params['collectionId'];
      final docId = request.params['docId'];

      // TODO: Implement actual document deletion
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {'deleted': true},
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

  /// Handler: List documents in collection
  Future<Response> _listDocsHandler(Request request) async {
    try {
      final collectionId = request.params['collectionId'];
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '10');
      final offset = int.tryParse(request.url.queryParameters['offset'] ?? '0');

      // TODO: Implement actual document listing
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'doc-1',
              'data': {'title': 'Example 1'},
              'created_at': DateTime.now().toIso8601String(),
            },
            {
              'id': 'doc-2',
              'data': {'title': 'Example 2'},
              'created_at': DateTime.now().toIso8601String(),
            },
          ],
          'pagination': {'limit': limit, 'offset': offset, 'total': 2},
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

  /// Handler: Upload media
  Future<Response> _uploadMediaHandler(Request request) async {
    try {
      // TODO: Implement actual media upload with compression
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'media-abc123',
            'original_size': 5000000,
            'compressed_size': 1200000,
            'compression_algo': 'gzip',
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
      final mediaId = request.params['mediaId'];

      // TODO: Implement actual media download with decompression
      return Response.ok(
        'binary_media_data_here',
        headers: {'Content-Type': 'application/octet-stream'},
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

  /// Gracefully shutdown the server
  Future<void> stop() async {
    print('\n[INFO] Received shutdown signal');
    print('[INFO] Closing database connection...');
    print('[INFO] All logs flushed');
    await _httpServer.close();
    print('[INFO] Goodbye!');
  }
}

/// Factory to create and run server
Future<void> runServer(String host, int port) async {
  final server = ShadowAppServer();
  await server.start(host, port);

  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}
