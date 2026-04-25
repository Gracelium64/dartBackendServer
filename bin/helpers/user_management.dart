// bin/helpers/user_management.dart
// Helper functions for user management operations in the admin console

import 'dart:math';

import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/auth/auth_service.dart';
import 'package:shadow_app_backend/auth/password_utils.dart';
import 'package:shadow_app_backend/database/models.dart';
import 'terminal_ui.dart';

/// List all users in a formatted table
Future<void> listUsers(DatabaseManager database) async {
  try {
    final users = await database.getAllUsers();

    if (users.isEmpty) {
      TerminalUI.printWarning('No users found');
      await database.logAction(AuditLog(
        userId: 'admin_console',
        action: 'LIST',
        resourceType: 'user',
        resourceId: 'all',
        status: 'success',
      ));
      return;
    }

    final rows = users.map((user) {
      return [
        user.id,
        user.email,
        user.role,
        user.createdAt.toString().substring(0, 19),
      ];
    }).toList();

    TerminalUI.printTable(
      ['ID', 'Email', 'Role', 'Created'],
      rows,
    );
    TerminalUI.printSuccess('Total users: ${users.length}');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'user',
      resourceId: 'all',
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'user',
      resourceId: 'all',
      status: 'failed',
      errorMessage: e.toString(),
    ));
    rethrow;
  }
}

/// Add a new user interactively
Future<void> addUser(DatabaseManager database) async {
  TerminalUI.printHeader('Add New User');

  final email = TerminalUI.prompt('Email', required: true);
  final password = TerminalUI.promptPassword('Password');
  final role = TerminalUI.prompt('Role (user/admin)', required: false);

  try {
    final result = await AuthService.signup(email, password);
    if (result['success'] != true) {
      TerminalUI.printError(
          'Failed to create user: ${result['error'] ?? 'Unknown error'}');
      return;
    }

    // If role is not default 'user', update it
    if (role.isNotEmpty && role != 'user') {
      final user = await database.getUserByEmail(email);
      if (user != null) {
        await database.updateUserRole(user.id, role);
      }
    }

    TerminalUI.printSuccess('User created: $email');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'user',
      resourceId: email,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'CREATE',
      resourceType: 'user',
      resourceId: email,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to create user: $e');
  }
}

/// Delete a user by ID or email
Future<void> deleteUser(DatabaseManager database) async {
  TerminalUI.printHeader('Delete User');

  final identifier =
      TerminalUI.prompt('User ID / Short ID / Email', required: true);

  // Find user by exact ID, email, or unique ID prefix.
  final user = await _findUser(database, identifier);

  if (user == null) {
    TerminalUI.printError('User not found');
    return;
  }

  TerminalUI.printWarning('About to delete: ${user.email} (${user.id})');

  if (!TerminalUI.confirm('Are you sure?')) {
    TerminalUI.printWarning('Cancelled');
    return;
  }

  try {
    await database.deleteUser(user.id);
    TerminalUI.printSuccess('User deleted: ${user.email}');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'user',
      resourceId: user.id,
      status: 'success',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'DELETE',
      resourceType: 'user',
      resourceId: user.id,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to delete user: $e');
  }
}

/// Change a user's role
Future<void> changeUserRole(DatabaseManager database) async {
  TerminalUI.printHeader('Change User Role');

  final identifier =
      TerminalUI.prompt('User ID / Short ID / Email', required: true);

  // Find user by exact ID, email, or unique ID prefix.
  final user = await _findUser(database, identifier);

  if (user == null) {
    TerminalUI.printError('User not found');
    return;
  }

  print('Current role: ${user.role}');
  final newRole = TerminalUI.prompt('New role (user/admin)', required: true)
      .trim()
      .toLowerCase();

  if (newRole != 'user' && newRole != 'admin') {
    TerminalUI.printError('Invalid role. Must be "user" or "admin"');
    return;
  }

  try {
    await database.updateUserRole(user.id, newRole);
    TerminalUI.printSuccess('Role updated: ${user.email} → $newRole');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_role',
      resourceId: user.id,
      status: 'success',
      details: '${user.role} → $newRole',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_role',
      resourceId: user.id,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to update role: $e');
  }
}

/// Change a user's email address.
Future<void> changeUserEmail(DatabaseManager database) async {
  TerminalUI.printHeader('Change User Email');

  final identifier =
      TerminalUI.prompt('User ID / Short ID / Email', required: true);
  final user = await _findUser(database, identifier);

  if (user == null) {
    TerminalUI.printError('User not found');
    return;
  }

  final newEmail = TerminalUI.prompt(
    'New email',
    required: true,
    defaultValue: user.email,
  ).trim().toLowerCase();

  if (!_isValidEmail(newEmail)) {
    TerminalUI.printError('Invalid email format');
    return;
  }

  if (newEmail == user.email.toLowerCase()) {
    TerminalUI.printWarning('Email unchanged');
    return;
  }

  try {
    await database.updateUserEmail(user.id, newEmail);
    TerminalUI.printSuccess('Email updated: ${user.email} → $newEmail');
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_email',
      resourceId: user.id,
      status: 'success',
      details: '${user.email} → $newEmail',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_email',
      resourceId: user.id,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to update email: $e');
  }
}

/// Reset a user's password using either manual entry or a random password.
Future<void> resetUserPassword(DatabaseManager database) async {
  TerminalUI.printHeader('Reset User Password');

  final identifier =
      TerminalUI.prompt('User ID / Short ID / Email', required: true);
  final user = await _findUser(database, identifier);

  if (user == null) {
    TerminalUI.printError('User not found');
    return;
  }

  print('Reset password for: ${user.email} (${user.id})');
  print('1. Enter password manually');
  print('2. Generate random password');
  print('3. Cancel');
  final choice = TerminalUI.prompt('Choose option', required: true).trim();

  if (choice == '3') {
    TerminalUI.printWarning('Cancelled');
    return;
  }

  late String newPassword;
  late String resetMode;

  switch (choice) {
    case '1':
      final manualPassword = TerminalUI.promptPassword('New password');
      final confirmPassword = TerminalUI.promptPassword('Confirm password');
      if (manualPassword != confirmPassword) {
        TerminalUI.printError('Passwords do not match');
        return;
      }
      if (manualPassword.length < 8) {
        TerminalUI.printError('Password must be at least 8 characters');
        return;
      }
      newPassword = manualPassword;
      resetMode = 'manual';
      break;
    case '2':
      newPassword = _generateRandomPassword();
      resetMode = 'random';
      break;
    default:
      TerminalUI.printError('Invalid choice');
      return;
  }

  try {
    final passwordHash = PasswordUtils.hashPassword(newPassword);
    await database.updateUserPasswordHash(user.id, passwordHash);
    TerminalUI.printSuccess('Password reset for ${user.email}');
    if (resetMode == 'random') {
      TerminalUI.printWarning('Generated password: $newPassword');
      TerminalUI.printWarning(
          'Store the generated password securely before leaving this screen.');
    }
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_password',
      resourceId: user.id,
      status: 'success',
      details: 'password reset via $resetMode flow',
    ));
  } catch (e) {
    await database.logAction(AuditLog(
      userId: 'admin_console',
      action: 'UPDATE',
      resourceType: 'user_password',
      resourceId: user.id,
      status: 'failed',
      errorMessage: e.toString(),
    ));
    TerminalUI.printError('Failed to reset password: $e');
  }
}

Future<User?> _findUser(DatabaseManager database, String identifier) async {
  final normalized = identifier.trim();
  if (normalized.isEmpty) {
    return null;
  }

  // First try exact ID and exact email lookups.
  var user = await database.getUserById(normalized);
  user ??= await database.getUserByEmail(normalized.toLowerCase());
  if (user != null) {
    return user;
  }

  // If it doesn't look like an email, allow unique ID-prefix matches.
  if (!normalized.contains('@')) {
    final allUsers = await database.getAllUsers();
    final lowerPrefix = normalized.toLowerCase();
    final matches = allUsers
        .where((u) => u.id.toLowerCase().startsWith(lowerPrefix))
        .toList();

    if (matches.length == 1) {
      return matches.first;
    }

    if (matches.length > 1) {
      TerminalUI.printError(
        'Ambiguous short ID. ${matches.length} users match "$normalized".',
      );
      final preview =
          matches.take(5).map((u) => '${u.email} (${u.id})').join(', ');
      print('Matches: $preview${matches.length > 5 ? ', ...' : ''}');
    }
  }

  return null;
}

bool _isValidEmail(String email) {
  return email.contains('@') && email.contains('.');
}

String _generateRandomPassword({int length = 20}) {
  const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^*-_';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}
