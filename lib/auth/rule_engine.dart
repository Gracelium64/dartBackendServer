// lib/auth/rule_engine.dart
// Rule engine for per-collection access control
// Explanation for Flutter Developers:
// Similar to Firebase Firestore security rules, but simpler.
// Collections have rules defining who can read/write. The rule engine
// evaluates these rules before allowing operations.

import '../database/models.dart';

/// Rule engine for access control
/// Evaluates read/write permissions on collections
class RuleEngine {
  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList();
  }

  /// Check if user can read from a collection
  static bool canRead(String userId, String userRole, Collection collection) {
    // Admin can read everything
    if (userRole == 'admin') return true;

    // Check if collection has public_read enabled
    if (collection.rules['public_read'] == true) return true;

    // Check if user is owner
    if (collection.ownerId == userId) return true;

    // Check if user's role is in read list
    final readRoles = _asStringList(collection.rules['read']);
    if (readRoles.contains(userRole)) return true;

    // Any non-empty user identity can satisfy authenticated access.
    if (readRoles.contains('authenticated') && userId.isNotEmpty) return true;

    // Check if user is specifically allowed (if rules contain user ID)
    if (readRoles.contains(userId)) return true;

    return false;
  }

  /// Check if user can write to a collection
  static bool canWrite(String userId, String userRole, Collection collection) {
    // Admin can write to everything
    if (userRole == 'admin') return true;

    // Check if user is owner
    if (collection.ownerId == userId) return true;

    // Check if user's role is in write list
    final writeRoles = _asStringList(collection.rules['write']);
    if (writeRoles.contains(userRole)) return true;

    // Any non-empty user identity can satisfy authenticated access.
    if (writeRoles.contains('authenticated') && userId.isNotEmpty) return true;

    // Check if user is specifically allowed (if rules contain user ID)
    if (writeRoles.contains(userId)) return true;

    return false;
  }

  /// Check if user can delete a collection
  static bool canDelete(String userId, String userRole, Collection collection) {
    // Admin can delete everything
    if (userRole == 'admin') return true;

    // Only owner can delete
    if (collection.ownerId == userId) return true;

    return false;
  }

  /// Get default rules for a new collection
  static Map<String, dynamic> defaultRules() {
    return {
      'read': ['admin', 'owner'],
      'write': ['admin', 'owner'],
      'public_read': false,
    };
  }

  /// Create rules allowing public read access
  static Map<String, dynamic> publicReadRules() {
    return {
      'read': ['admin', 'owner', 'public'],
      'write': ['admin', 'owner'],
      'public_read': true,
    };
  }

  /// Create rules allowing all authenticated users to read
  static Map<String, dynamic> authenticatedReadRules() {
    return {
      'read': ['admin', 'owner', 'user'],
      'write': ['admin', 'owner'],
      'public_read': false,
    };
  }

  /// Validate and sanitize rules
  static Map<String, dynamic> validateRules(Map<String, dynamic> rules) {
    final validated = {...defaultRules()};

    if (rules['read'] is List) {
      validated['read'] = rules['read'];
    }

    if (rules['write'] is List) {
      validated['write'] = rules['write'];
    }

    if (rules['public_read'] is bool) {
      validated['public_read'] = rules['public_read'];
    }

    return validated;
  }
}
