// bin/helpers/user_management.dart
// Helper functions for user management operations in the admin console

import 'package:shadow_app_backend/database/db_manager.dart';
import 'package:shadow_app_backend/auth/auth_service.dart';
import 'package:shadow_app_backend/database/models.dart';
import 'package:shadow_app_backend/logging/logger.dart';
import 'terminal_ui.dart';

/// List all users in a formatted table
Future<void> listUsers(DatabaseManager database) async {
  try {
    final users = await database.getAllUsers();

    if (users.isEmpty) {
      TerminalUI.printWarning('No users found');
      await logger.logAction(AuditLog(
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
    await logger.logAction(AuditLog(
      userId: 'admin_console',
      action: 'LIST',
      resourceType: 'user',
      resourceId: 'all',
      status: 'success',
    ));
  } catch (e) {
    await logger.logAction(AuditLog(
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
  } catch (e) {
    TerminalUI.printError('Failed to create user: $e');
  }
}

/// Delete a user by ID or email
Future<void> deleteUser(DatabaseManager database) async {
  TerminalUI.printHeader('Delete User');

  final identifier = TerminalUI.prompt('User ID or Email', required: true);

  // Find user by ID or email
  var user = await database.getUserById(identifier);
  user ??= await database.getUserByEmail(identifier);

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
  } catch (e) {
    TerminalUI.printError('Failed to delete user: $e');
  }
}

/// Change a user's role
Future<void> changeUserRole(DatabaseManager database) async {
  TerminalUI.printHeader('Change User Role');

  final identifier = TerminalUI.prompt('User ID or Email', required: true);

  // Find user
  var user = await database.getUserById(identifier);
  user ??= await database.getUserByEmail(identifier);

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
  } catch (e) {
    TerminalUI.printError('Failed to update role: $e');
  }
}
