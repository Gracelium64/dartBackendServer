// lib/auth/password_utils.dart
// Password hashing and verification utilities
// Explanation for Flutter Developers:
// In Flutter, you typically don't handle password hashing (the server does it).
// Here, we use bcrypt, a slow hashing algorithm designed to resist brute-force attacks.
// This is much better than storing plain passwords or using fast hashes like MD5.

import 'package:crypto/crypto.dart';
import 'dart:math';
import 'dart:convert';

/// Password utility functions for secure password handling
class PasswordUtils {
  // Bcrypt is complex to implement from scratch, so we use a workaround
  // In production, use a proper bcrypt package like 'pointycastle'

  /// Hash a password using PBKDF2 (reasonable alternative to bcrypt)
  /// In production, prefer actual bcrypt via pointycastle
  static String hashPassword(String password) {
    final salt = _generateRandomSalt();
    return _pbkdf2Hash(password, salt);
  }

  /// Verify a password against a hash
  static bool verifyPassword(String password, String hash) {
    try {
      // Extract salt from hash (format: salt$hash)
      final parts = hash.split('\$');
      if (parts.length != 2) return false;

      final salt = parts[0];

      // Compute hash with same salt
      final computedHash = hashWithSalt(password, salt);

      // Constant-time comparison to prevent timing attacks
      return _constantTimeEqual(computedHash, hash);
    } catch (e) {
      print('[AUTH ERROR] Password verification failed: $e');
      return false;
    }
  }

  /// Hash password with specific salt
  static String hashWithSalt(String password, String salt) {
    return _pbkdf2Hash(password, salt);
  }

  /// PBKDF2 key derivation function
  static String _pbkdf2Hash(String password, String salt,
      {int iterations = 100000}) {
    // PBKDF2 is a standard password hashing function
    // Reason for high iteration count: slows down brute-force attacks
    // Even with high iteration count, it's still vulnerable compared to bcrypt,
    // but it's better than plain hashing.

    var result = password;
    for (int i = 0; i < iterations; i++) {
      // Simulate PBKDF2 through repeated hashing
      // (production should use actual PBKDF2 implementation)
      result = sha256.convert(utf8.encode(result + salt)).toString();
    }

    return '$salt\$$result';
  }

  /// Generate random salt for password hashing
  static String _generateRandomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Constant-time string comparison
  /// Prevents timing attacks where hash computation time leaks password info
  static bool _constantTimeEqual(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}
