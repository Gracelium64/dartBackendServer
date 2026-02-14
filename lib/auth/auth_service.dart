// lib/auth/auth_service.dart
// Authentication service - JWT token generation and validation
// Explanation for Flutter Developers:
// In a Flutter app, when you submit login credentials to a server, the server
// responds with a token (JWT). Your app stores it and includes it in future requests.
// This file shows how the server creates and validates those tokens.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'password_utils.dart';
import '../database/models.dart';
import '../database/db_manager.dart';
import '../config.dart';

/// Authentication service
class AuthService {
  /// Sign up a new user
  /// Returns: {success: true/false, user: User?, token: String?, error: String?}
  static Future<Map<String, dynamic>> signup(
      String email, String password) async {
    try {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        return {'success': false, 'error': 'Email and password required'};
      }

      if (password.length < 8) {
        return {'success': false, 'error': 'Password must be at least 8 characters'};
      }

      if (!_isValidEmail(email)) {
        return {'success': false, 'error': 'Invalid email format'};
      }

      // Check if user already exists
      final existingUser = await database.getUserByEmail(email);
      if (existingUser != null) {
        return {'success': false, 'error': 'User already exists'};
      }

      // Hash password
      final passwordHash = PasswordUtils.hashPassword(password);

      // Create user
      final newUser = User(
        email: email,
        passwordHash: passwordHash,
        role: 'user',
      );

      final createdUser = await database.createUser(newUser);

      // Generate token
      final token = generateToken(createdUser.id, createdUser.email);

      return {
        'success': true,
        'user': {
          'id': createdUser.id,
          'email': createdUser.email,
          'role': createdUser.role,
        },
        'token': token,
      };
    } catch (e) {
      print('[AUTH ERROR] Signup failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Log in a user
  /// Returns: {success: true/false, user: User?, token: String?, error: String?}
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return {'success': false, 'error': 'Email and password required'};
      }

      // Find user by email
      final user = await database.getUserByEmail(email);
      if (user == null) {
        return {'success': false, 'error': 'User not found'};
      }

      // Verify password
      if (!PasswordUtils.verifyPassword(password, user.passwordHash)) {
        return {'success': false, 'error': 'Invalid password'};
      }

      // Generate token
      final token = generateToken(user.id, user.email);

      return {
        'success': true,
        'user': {
          'id': user.id,
          'email': user.email,
          'role': user.role,
        },
        'token': token,
      };
    } catch (e) {
      print('[AUTH ERROR] Login failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Refresh an existing token
  static Future<Map<String, dynamic>> refreshToken(String token) async {
    try {
      final claims = validateToken(token);
      if (claims == null) {
        return {'success': false, 'error': 'Invalid token'};
      }

      final userId = claims['sub'] as String;
      final user = await database.getUserById(userId);
      if (user == null) {
        return {'success': false, 'error': 'User not found'};
      }

      // Generate new token
      final newToken = generateToken(user.id, user.email);

      return {
        'success': true,
        'token': newToken,
      };
    } catch (e) {
      print('[AUTH ERROR] Token refresh failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generate a JWT token
  /// Format: header.payload.signature (all base64url encoded)
  /// Explanation: JWT is a self-contained token that can be verified by checking
  /// the signature without querying the database every time.
  static String generateToken(String userId, String email) {
    final now = DateTime.now();
    final exp = now.add(Duration(hours: globalConfig.jwtExpiryHours));

    // Header
    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    // Payload (claims)
    final payload = {
      'sub': userId, // subject (user ID)
      'email': email,
      'iat': (now.millisecondsSinceEpoch / 1000).toInt(), // issued at
      'exp': (exp.millisecondsSinceEpoch / 1000).toInt(), // expiration
    };

    // Encode header and payload
    final encodedHeader = _base64UrlEncode(jsonEncode(header));
    final encodedPayload = _base64UrlEncode(jsonEncode(payload));
    final message = '$encodedHeader.$encodedPayload';

    // Create signature using secret key
    // HMAC-SHA256 = Hash-based Message Authentication Code using SHA256
    // This proves the token wasn't tampered with
    final signature = _base64UrlEncode(
      utf8.encode(
        Hmac(sha256, utf8.encode(globalConfig.jwtSecret))
            .convert(utf8.encode(message))
            .toString(),
      ),
    );

    return '$message.$signature';
  }

  /// Validate and decode a JWT token
  /// Returns: payload map if valid, null if invalid
  static Map<String, dynamic>? validateToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('[AUTH] Invalid token format');
        return null;
      }

      final header = jsonDecode(_base64UrlDecode(parts[0])) as Map;
      final payload = jsonDecode(_base64UrlDecode(parts[1])) as Map<String, dynamic>;
      final signature = parts[2];

      // Verify signature
      final message = '${parts[0]}.${parts[1]}';
      final expectedSignature = _base64UrlEncode(
        utf8.encode(
          Hmac(sha256, utf8.encode(globalConfig.jwtSecret))
              .convert(utf8.encode(message))
              .toString(),
        ),
      );

      if (signature != expectedSignature) {
        print('[AUTH] Signature mismatch');
        return null;
      }

      // Check expiration
      final exp = payload['exp'] as int?;
      if (exp == null) {
        print('[AUTH] Missing expiration');
        return null;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (expiry.isBefore(DateTime.now())) {
        print('[AUTH] Token expired');
        return null;
      }

      return payload;
    } catch (e) {
      print('[AUTH ERROR] Token validation failed: $e');
      return null;
    }
  }

  /// Check if email format is valid
  static bool _isValidEmail(String email) {
    // Simple email validation (production should use more robust regex)
    return email.contains('@') && email.contains('.');
  }

  /// Base64url encode (JWT standard)
  static String _base64UrlEncode(dynamic data) {
    final bytes = data is String ? utf8.encode(data) : data as List<int>;
    return base64Url
        .encode(bytes)
        .toString()
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  /// Base64url decode (JWT standard)
  static String _base64UrlDecode(String str) {
    // Add back padding
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Invalid base64url');
    }

    return utf8.decode(base64Url.decode(output));
  }
}
