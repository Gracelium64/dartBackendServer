// flutter_sdk/lib/shadow_app.dart
// Main entry point for Shadow App Backend Flutter SDK
// For Flutter Developers: This is your main interface to the backend.
// It provides simple methods for CRUD operations, authentication, and media handling.

import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'crud_service.dart';
import 'media_service.dart';

/// Main ShadowApp class - your gateway to the backend
/// 
/// Usage:
/// ```dart
/// // Initialize once in main()
/// await ShadowApp.initialize(serverUrl: 'http://192.168.1.100:8080');
/// 
/// // Login
/// await ShadowApp.auth.login('user@example.com', 'password');
/// 
/// // Use collections
/// final doc = await ShadowApp.collection('notes').create({'title': 'My Note'});
/// ```
class ShadowApp {
  static final ShadowApp _instance = ShadowApp._internal();
  
  late String _serverUrl;
  late SharedPreferences _prefs;
  
  // Public services
  late AuthService _authService;
  late MediaService _mediaService;

  factory ShadowApp() {
    return _instance;
  }

  ShadowApp._internal();

  /// Initialize the SDK (call this once in your app's main() function)
  static Future<void> initialize({
    required String serverUrl,
    bool enableOfflineMode = true,
  }) async {
    _instance._serverUrl = serverUrl;
    _instance._prefs = await SharedPreferences.getInstance();
    _instance._authService = AuthService(
      serverUrl: serverUrl,
      prefs: _instance._prefs,
    );
    _instance._mediaService = MediaService(
      serverUrl: serverUrl,
      prefs: _instance._prefs,
    );
  }

  /// Access auth methods (login, signup, logout, etc.)
  static AuthService get auth => _instance._authService;

  /// Access media methods (upload, download)
  static MediaService get media => _instance._mediaService;

  /// Get or create a collection reference
  static CrudService collection(String collectionId) {
    return CrudService(
      collectionId: collectionId,
      serverUrl: _instance._serverUrl,
      prefs: _instance._prefs,
    );
  }

  /// Get server URL
  static String get serverUrl => _instance._serverUrl;

  /// Check if initialized
  static bool get isInitialized {
    try {
      return _instance._serverUrl.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

/// Configuration class for advanced settings
class ShadowAppConfig {
  /// Enable local caching of documents
  static bool enableOfflineMode = true;

  /// Timeout for network requests (seconds)
  static int networkTimeout = 30;

  /// Enable detailed logging
  static bool enableDebugLogging = false;

  /// Compression quality for media (0.0 to 1.0)
  static double mediaCompressionQuality = 0.85;
}

/// Exception thrown by SDK operations
class ShadowAppException implements Exception {
  final String message;
  final dynamic originalError;

  ShadowAppException({required this.message, this.originalError});

  @override
  String toString() => 'ShadowAppException: $message';
}

/// Network exception
class NetworkException extends ShadowAppException {
  NetworkException({required String message, dynamic originalError})
      : super(message: message, originalError: originalError);
}

/// Authentication exception
class AuthException extends ShadowAppException {
  AuthException({required String message, dynamic originalError})
      : super(message: message, originalError: originalError);
}

/// Validation exception
class ValidationException extends ShadowAppException {
  ValidationException({required String message, dynamic originalError})
      : super(message: message, originalError: originalError);
}
