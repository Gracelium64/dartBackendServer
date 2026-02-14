// flutter_sdk/lib/auth_service.dart
// Authentication service for Flutter SDK
// For Flutter Developers: This handles login, signup, token refresh, and logout.

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'shadow_app.dart';

/// User data model
class AuthUser {
  final String id;
  final String email;
  final String role;

  AuthUser({
    required this.id,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'user',
    );
  }
}

/// Authentication service
class AuthService {
  final String serverUrl;
  final SharedPreferences prefs;
  
  static const String _tokenKey = 'shadow_app_token';
  static const String _userKey = 'shadow_app_user';

  AuthUser? _currentUser;
  String? _token;

  AuthService({
    required this.serverUrl,
    required this.prefs,
  }) {
    // Load stored token and user on initialization
    _loadStoredAuth();
  }

  /// Load previously stored token and user
  void _loadStoredAuth() {
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      try {
        _currentUser = AuthUser.fromJson(jsonDecode(userJson));
      } catch (e) {
        if (ShadowAppConfig.enableDebugLogging) {
          print('[AUTH] Failed to load stored user: $e');
        }
      }
    }
  }

  /// Sign up a new user
  Future<AuthUser> signup({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw ValidationException(
        message: 'Email and password required',
        originalError: null,
      );
    }

    if (password.length < 8) {
      throw ValidationException(
        message: 'Password must be at least 8 characters',
        originalError: null,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw AuthException(
          message: error['error'] ?? 'Signup failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw AuthException(
          message: data['error'] ?? 'Signup failed',
          originalError: data,
        );
      }

      // Store token and user
      _token = data['data']['token'];
      _currentUser = AuthUser.fromJson(data['data']);

      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey, jsonEncode(data['data']));

      if (ShadowAppConfig.enableDebugLogging) {
        print('[AUTH] Signup successful for ${_currentUser!.email}');
      }

      return _currentUser!;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Signup failed: $e',
        originalError: e,
      );
    }
  }

  /// Log in a user
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw ValidationException(
        message: 'Email and password required',
        originalError: null,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw AuthException(
          message: error['error'] ?? 'Login failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw AuthException(
          message: data['error'] ?? 'Login failed',
          originalError: data,
        );
      }

      // Store token and user
      _token = data['data']['token'];
      _currentUser = AuthUser.fromJson(data['data']);

      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey, jsonEncode(data['data']));

      if (ShadowAppConfig.enableDebugLogging) {
        print('[AUTH] Login successful for ${_currentUser!.email}');
      }

      return _currentUser!;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Login failed: $e',
        originalError: e,
      );
    }
  }

  /// Refresh the current token
  Future<String> refreshToken() async {
    if (_token == null) {
      throw AuthException(
        message: 'No token to refresh',
        originalError: null,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$serverUrl/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_token',
            },
          )
          .timeout(Duration(seconds: ShadowAppConfig.networkTimeout));

      if (response.statusCode != 200) {
        throw AuthException(
          message: 'Token refresh failed',
          originalError: response.body,
        );
      }

      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw AuthException(
          message: 'Token refresh failed',
          originalError: data,
        );
      }

      _token = data['data']['token'];
      await prefs.setString(_tokenKey, _token!);

      if (ShadowAppConfig.enableDebugLogging) {
        print('[AUTH] Token refreshed');
      }

      return _token!;
    } catch (e) {
      if (e is ShadowAppException) rethrow;
      throw NetworkException(
        message: 'Token refresh failed: $e',
        originalError: e,
      );
    }
  }

  /// Log out user
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    if (ShadowAppConfig.enableDebugLogging) {
      print('[AUTH] Logged out');
    }
  }

  /// Get current user
  AuthUser? get currentUser => _currentUser;

  /// Check if logged in
  bool get isLoggedIn => _token != null && _currentUser != null;

  /// Get current token (for advanced usage)
  String? get token => _token;

  /// Set token (useful for restoring from external source)
  Future<void> setToken(String newToken, AuthUser user) async {
    _token = newToken;
    _currentUser = user;
    await prefs.setString(_tokenKey, newToken);
    await prefs.setString(_userKey, jsonEncode({
      'id': user.id,
      'email': user.email,
      'role': user.role,
    }));
  }
}
