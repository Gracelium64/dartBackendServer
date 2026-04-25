# Shadow App Backend - Flutter SDK Guide

**Version:** 0.1.0  
**Package:** `shadow_app_backend`  
**License:** MIT

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [SDK Architecture](#sdk-architecture)
5. [Configuration](#configuration)
6. [Authentication](#authentication)
7. [Document Operations](#document-operations)
8. [Media Handling](#media-handling)
9. [API Reference](#api-reference)
10. [Dart Types](#dart-types)
11. [Error Handling](#error-handling)
12. [State Management](#state-management)
13. [Best Practices](#best-practices)
14. [Operator Coordination](#operator-coordination)
15. [Comparison with React SDK](#comparison-with-react-sdk)

---

## Overview

The Shadow App Flutter SDK is a Dart-native client library for integrating with the Shadow App Dart Backend Server. It provides a complete set of tools for modern Flutter applications including:

- 🔐 **Authentication** - JWT-based auth with automatic token refresh
- 📄 **Document CRUD** - Full create, read, update, delete operations
- 📁 **Media Handling** - File upload/download with compression
- 🧠 **Admin SQL Blocks** - Admin-only SQL execution (up to 5 statements)
- 💾 **Offline Support** - Local caching with server sync
- 🎯 **Singleton Pattern** - Simple static method access
- 🛠️ **Developer Friendly** - Intuitive API similar to Firebase
- ⚡ **Auto Compression** - Automatic image optimization
- 📱 **Cross-Platform** - iOS, Android, Web, Desktop

### Why Use the Flutter SDK?

For **Flutter developers**, this SDK provides:

- Native Dart code with no JavaScript bridge
- Singleton pattern similar to Firebase
- Seamless integration with Flutter state management
- SharedPreferences for persistent storage
- Similar to Firebase, but with complete backend transparency and learning value

For **Mobile developers**, this SDK provides:

- Native mobile performance
- Automatic image compression
- Offline-first capabilities
- Local storage with SharedPreferences
- Cross-platform (iOS + Android + Web + Desktop)

### Current Server Access Points

- Production base URL: `https://shadow-app-server.onrender.com`
- Local/dev base URL template: `http://SERVER_IP:PORT` (example: `http://localhost:8080`)

Authentication and access:

- JWT bearer auth for normal app operations: `Authorization: Bearer <token>`
- Admin key auth for operator tooling: `X-Admin-Key: <admin_key>`
- Public endpoints (no auth): `/health`, `/auth/signup`, `/auth/login`, `/api/logs/recent`, `/api/logs/stream`

SDK endpoint coverage status:

- Covered by Flutter SDK: auth (`/auth/signup`, `/auth/login`, `/auth/refresh`), document CRUD, media upload/download/metadata, admin SQL (`/api/admin/sql-query`)
- Not exposed as high-level SDK methods: `/api/users`, `/api/logs/stream`

---

## Installation

### Method 1: Local Path (Development)

In your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shadow_app_backend:
    path: ../dartBackendServer/flutter_sdk
```

### Method 2: Git Repository (Recommended)

```yaml
dependencies:
  flutter:
    sdk: flutter
  shadow_app_backend:
    git:
      url: https://github.com/Gracelium64/dartBackendServer.git
      path: flutter_sdk
```

### Method 3: Pub.dev (Future)

```yaml
dependencies:
  flutter:
    sdk: flutter
  shadow_app_backend: ^0.1.0
```

### Fetch Dependencies

```bash
flutter pub get
```

### Import in Dart Files

```dart
import 'package:shadow_app_backend/shadow_app.dart';
```

---

## Quick Start

### Step 1: Initialize the SDK

In your app's `main()` function:

```dart
import 'package:flutter/material.dart';
import 'package:shadow_app_backend/shadow_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Shadow App SDK
  await ShadowApp.initialize(
    serverUrl: 'http://192.168.1.100:8080',  // Your backend server URL
    enableOfflineMode: true,                 // Optional: enable local caching
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow App Demo',
      home: const HomeScreen(),
    );
  }
}
```

### Step 2: Authenticate

```dart
import 'package:shadow_app_backend/shadow_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final user = await ShadowApp.auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      print('Logged in as: ${user.email}');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 3: CRUD Operations

```dart
class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<ShadowDocument> _notes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await ShadowApp.collection('notes').list();
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createNote() async {
    final newNote = await ShadowApp.collection('notes').create({
      'title': 'New Note',
      'content': 'Enter your content here...',
      'createdAt': DateTime.now().toIso8601String(),
    });

    setState(() => _notes.add(newNote));
  }

  Future<void> _deleteNote(String noteId) async {
    await ShadowApp.collection('notes').delete(noteId);
    setState(() => _notes.removeWhere((note) => note.id == noteId));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Notes')),
      body: ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return ListTile(
            title: Text(note.data['title'] ?? 'Untitled'),
            subtitle: Text(note.data['content'] ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteNote(note.id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## SDK Architecture

### File Structure

```
flutter_sdk/
├── lib/
│   ├── shadow_app.dart       # Main entry point & singleton
│   ├── auth_service.dart     # Authentication methods
│   ├── crud_service.dart     # CRUD operations per collection
│   └── media_service.dart    # Media upload/download
├── pubspec.yaml              # Package configuration
└── README.md                 # Basic documentation
```

### Architecture Components

1. **ShadowApp** (`shadow_app.dart`)
   - Singleton class with static methods
   - Entry point for all SDK operations
   - Manages initialization and configuration

2. **AuthService** (`auth_service.dart`)
   - Signup, login, logout
   - Token management and refresh
   - Persistent session storage

3. **CrudService** (`crud_service.dart`)
   - Per-collection CRUD operations
   - Offline caching support
   - Pagination and filtering

4. **MediaService** (`media_service.dart`)
   - File upload with compression
   - Download and caching
   - Metadata management

### Singleton Pattern

Unlike React's Context Provider, Flutter SDK uses a singleton pattern:

```dart
// One global instance
ShadowApp.initialize(serverUrl: '...');

// Access from anywhere
ShadowApp.auth.login(...);
ShadowApp.collection('notes').create(...);
ShadowApp.media.upload(...);
```

---

## Configuration

### ShadowAppConfig Class

```dart
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
```

### Configuration Examples

#### Basic Configuration

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ShadowApp.initialize(
    serverUrl: 'http://localhost:8080',
  );

  runApp(const MyApp());
}
```

#### Production Configuration

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ShadowApp.initialize(
    serverUrl: const String.fromEnvironment('API_URL',
        defaultValue: 'https://api.myapp.com'),
    enableOfflineMode: true,
  );

  // Configure advanced options
  ShadowAppConfig.networkTimeout = 60; // 60 seconds for slow networks
  ShadowAppConfig.mediaCompressionQuality = 0.9; // Higher quality

  runApp(const MyApp());
}
```

#### Development Configuration with Debugging

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ShadowApp.initialize(
    serverUrl: 'http://192.168.1.100:8080', // Local network IP
    enableOfflineMode: false, // Disable caching for testing
  );

  // Enable debug logging
  ShadowAppConfig.enableDebugLogging = true;
  ShadowAppConfig.networkTimeout = 5; // Fast failure for development

  runApp(const MyApp());
}
```

### Environment-Based Configuration

```dart
// lib/config.dart
class AppConfig {
  static String get apiUrl {
    if (kReleaseMode) {
      return 'https://api.myapp.com';
    } else if (kProfileMode) {
      return 'https://staging-api.myapp.com';
    } else {
      return 'http://192.168.1.100:8080';
    }
  }
}

// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShadowApp.initialize(serverUrl: AppConfig.apiUrl);
  runApp(const MyApp());
}
```

---

## Authentication

### Operator-Managed Account Changes

The backend admin console can now change a user's login email and reset a user's password.

For Flutter apps, that means:

- Your login form should treat email as mutable account data, not a permanent identifier cached forever.
- If an operator resets the password, the user must use the new password on the next login.
- Existing access tokens continue until expiry; after that, your app should send the user back through normal login.
- Password resets and email changes are not Flutter SDK methods; they are administrative backend actions.

### Signup

Create a new user account:

````dart
class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signup() async {
    // Validate passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ShadowApp.auth.signup(
        email: _emailController.text,
        password: _passwordController.text,
      );

      print('Account created: ${user.email}');
      // User is automatically logged in

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Signup failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

#### Log Out

```dart
Future<void> logoutUser() async {
  await ShadowApp.auth.logout();
  print('Logged out');
}
````

#### Check Authentication Status

```dart
bool isLoggedIn = ShadowApp.auth.isLoggedIn;
String? currentUserEmail = ShadowApp.auth.currentUser?.email;
```

## CRUD Operations

The SDK treats your data as **Collections** (like tables) containing **Documents** (like rows).

### Create a Document

Create a document in a collection:

```dart
// Access collection
final notesCollection = ShadowApp.collection('notes');

// Create a new document
final newNote = await notesCollection.create({
  'title': 'My First Note',
  'content': 'This is a test note',
  'tags': ['flutter', 'learning'],
  'createdAt': DateTime.now().toIso8601String(),
});

print('Document created with ID: ${newNote.id}');
print('Data: ${newNote.data}');
```

**Output:**

```
Document created with ID: doc-a1b2c3d4e5f6
Data: {
  "title": "My First Note",
  "content": "This is a test note",
  "tags": ["flutter", "learning"],
  "createdAt": "2026-02-14T10:30:00Z"
}
```

### Read a Document

Fetch a single document by ID:

```dart
final noteId = 'doc-a1b2c3d4e5f6';
final note = await ShadowApp.collection('notes').read(noteId);

print('Title: ${note.data['title']}');
print('Content: ${note.data['content']}');
```

### Read Multiple Documents (List)

Fetch all documents from a collection with pagination:

```dart
final notes = await ShadowApp.collection('notes').list(
  limit: 10,
  offset: 0,
);

for (final note in notes) {
  print('${note.id}: ${note.data['title']}');
}
```

With filtering (note: basic filtering, server-side):

```dart
final filterCriteria = {
  'tags': ['flutter']  // Backend will filter documents
};
final filteredNotes = await ShadowApp.collection('notes').list(
  where: filterCriteria,
);
```

### Update a Document

Modify an existing document:

```dart
final noteId = 'doc-a1b2c3d4e5f6';

final updatedNote = await ShadowApp.collection('notes').update(
  noteId,
  {
    'content': 'Updated content here',
    'updatedAt': DateTime.now().toIso8601String(),
  },
  // If merge=true, updates fields; if false, replaces entire document
  merge: true,
);

print('Updated: ${updatedNote.data['content']}');
```

### Delete a Document

Remove a document:

```dart
final noteId = 'doc-a1b2c3d4e5f6';
await ShadowApp.collection('notes').delete(noteId);
print('Document deleted');
```

### Delete Collection

Remove an entire collection and all its documents:

```dart
final collectionId = 'notes';
try {
  await ShadowApp.deleteCollection(collectionId);
  print('Collection deleted');
} catch (e) {
  print('Delete failed: $e');
}
```

> **Note**: You must own the collection or be an admin to delete it. Deleting a collection cascades to all its documents and associated media.

## Media Operations

Upload images, videos, or files directly into the database with automatic compression.

### Upload Media

```dart
import 'package:image_picker/image_picker.dart';

Future<void> uploadProfileImage() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    try {
      final media = await ShadowApp.media.upload(
        filePath: pickedFile.path,
        destinationCollection: 'users',
        destinationDocId: 'user-xyz123',  // Your user ID
        mediaType: 'image/jpeg',
      );

      print('Uploaded: ${media.id}');
      print('Original size: ${media.originalSize} bytes');
      print('Compressed size: ${media.compressedSize} bytes');
      print('Compression: ${media.compressionAlgo}');
    } catch (e) {
      print('Upload failed: $e');
    }
  }
}
```

The SDK automatically:

- Compresses the image (JPEG to optimized JPEG, PNG to compressed PNG)
- Uploads to server
- Stores in the specified document
- Returns metadata

### Download Media

```dart
Future<void> downloadProfileImage(String mediaId) async {
  try {
    final bytes = await ShadowApp.media.download(mediaId);

    // Save to local file
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/profile_image.jpg');
    await file.writeAsBytes(bytes);

    print('Downloaded and saved: ${file.path}');
  } catch (e) {
    print('Download failed: $e');
  }
}
```

### Get Media Metadata

```dart
final mediaInfo = await ShadowApp.media.getMetadata('media-abc123');
print('Original size: ${mediaInfo.originalSize} bytes');
print('Compressed size: ${mediaInfo.compressedSize} bytes');
print('Compression ratio: ${(mediaInfo.compressedSize / mediaInfo.originalSize * 100).toStringAsFixed(1)}%');
```

## Error Handling

All SDK methods throw exceptions. Handle them appropriately:

```dart
try {
  final user = await ShadowApp.auth.login(email, password);
} on AuthException catch (e) {
  print('Auth error: ${e.message}');
  // Handle: invalid credentials, user not found, etc.
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
  // Handle: server unreachable, timeout, etc.
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  // Handle: bad email format, weak password, etc.
} catch (e) {
  print('Unknown error: $e');
}
```

## Advanced: Understanding the Internals

### How Authentication Works

Behind the scenes:

1. **Signup**: You send email + password to `/auth/signup`
   - Backend hashes password with bcrypt (irreversible one-way hash)
   - Stores user in database
   - Returns a JWT (JSON Web Token)

2. **Login**: You send email + password to `/auth/login`
   - Backend retrieves password hash, compares with bcrypt

- If match, generates JWT token (HS256 algorithm, configured expiry)
- Token is a signed, encrypted blob that proves your identity

3. **JWT Token**:

   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFiYzEyMyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsImV4cCI6MTYwMjM5NjU0N30.SflKxwRJSmYq...
   ```

- **Header**: Algorithm (HS256)
- **Payload**: User ID, email, expiration time
- **Signature**: Cryptographic proof server created this token

4. **Token Storage**: SDK stores token locally in `SharedPreferences` (Android) or `Keychain` (iOS)

5. **Token Usage**: Every API request includes the token in the `Authorization` header:

   ```
   Authorization: Bearer eyJhbGc...
   ```

   - Server validates signature and expiration
   - If valid, processes request as that user
   - If invalid/expired, returns 401 Unauthorized

### How CRUD Works

1. **Create**: POST to `/api/collections/{collectionId}/documents`

   ```
   Request body: { "title": "My Note", "content": "..." }
   Response: { "id": "doc-xyz", "data": { ... } }
   ```

2. **Read**: GET `/api/collections/{collectionId}/documents/{docId}`
   - Server checks: Does your token's user have read access?
   - Returns 403 Forbidden if rules deny access
   - Returns 200 OK with document data if allowed

3. **Update**: PUT `/api/collections/{collectionId}/documents/{docId}`

   ```
   Request body: { "title": "Updated" }
   Response: { "id": "doc-xyz", "data": { ... } }
   ```

4. **Delete**: DELETE `/api/collections/{collectionId}/documents/{docId}`
   - Full document removed from database
   - All associated media also deleted

### How Media Compression Works

When you upload an image:

1. **Client-side** (optional): SDK can pre-compress before upload (saves bandwidth)
2. **Server-side**: Backend receives raw bytes, applies compression:
   ```
   Original: image.jpg (2 MB)
   → JPEG recompression with quality=85
   → Gzip compression
   → Result: 400 KB (80% reduction)
   ```
3. **Storage**: Compressed blob stored in database
4. **Download**: Backend retrieves blob, decompresses, sends original quality

## Example: Complete Notes App

```dart
import 'package:flutter/material.dart';
import 'package:shadow_app_backend/shadow_app.dart';

void main() {
  ShadowApp.initialize(serverUrl: 'http://192.168.1.100:8080');
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      home: ShadowApp.auth.isLoggedIn
        ? const NotesScreen()
        : const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      await ShadowApp.auth.login(
        email: emailController.text,
        password: passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/notes');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<ShadowDocument>> futureNotes;

  @override
  void initState() {
    super.initState();
    futureNotes = _loadNotes();
  }

  Future<List<ShadowDocument>> _loadNotes() async {
    return await ShadowApp.collection('notes').list();
  }

  Future<void> _createNote() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateNoteDialog(),
    );
    if (result != null) {
      await ShadowApp.collection('notes').create({'title': result});
      setState(() => futureNotes = _loadNotes());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ShadowApp.auth.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ShadowDocument>>(
        future: futureNotes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final notes = snapshot.data ?? [];
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return ListTile(
                title: Text(note.data['title'] ?? 'Untitled'),
                onTap: () {
```

---

## API Reference

### AuthService

Complete authentication API:

```dart
// Signup
Future<AuthUser> signup({
  required String email,
  required String password,
}) async

// Login
Future<AuthUser> login({
  required String email,
  required String password,
}) async

// Logout
Future<void> logout() async

// Check login status
bool get isLoggedIn

// Get current user
AuthUser? get currentUser

// Get access token
Future<String?> getAccessToken() async

// Manually refresh token
Future<String> refreshTokenManually() async
```

### CrudService

Complete CRUD API for a collection:

```dart
// Create document
Future<ShadowDocument> create(Map<String, dynamic> data) async

// Read single document
Future<ShadowDocument> read(String docId) async

// Update document
Future<ShadowDocument> update(
  String docId,
  Map<String, dynamic> data, {
  bool merge = true,
}) async

// Delete document
Future<void> delete(String docId) async

// List documents with pagination
Future<List<ShadowDocument>> list({
  int limit = 50,
  int offset = 0,
  Map<String, dynamic>? where,
}) async
```

### MediaService

Complete media API:

```dart
// Upload file
Future<MediaUploadResult> upload({
  required String filePath,
  required String mediaType,
  Function(double progress)? onProgress,
}) async

// Download file
Future<Uint8List> download(String mediaId) async

// Get metadata
Future<MediaMetadata> getMetadata(String mediaId) async
```

### AdminSqlService (Admin Only)

Advanced SQL API:

```dart
// Execute SQL query block (up to 5 statements)
Future<AdminSqlResponse> execute(
  String sql, {
  List<Object?> params = const [],
  int? maxRowsOverride,
  bool disableRowCapOverride = false,
})

// Session-level row cap controls
void setSessionRowCap(int maxRows)
void disableSessionRowCap()
void resetSessionRowCapToDefault()
```

Example usage:

```dart
// Ensure logged in user is admin
await ShadowApp.auth.login(email: 'admin@example.com', password: 'pass');

// Optional session override
ShadowApp.adminSql.setSessionRowCap(1000);

final result = await ShadowApp.adminSql.execute(
  "DELETE FROM documents WHERE owner_id='legacy_user'; SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5",
);

for (final statement in result.statements) {
  print('Statement #${statement.statementIndex} -> ${statement.rowCount} row(s)');
}

// Disable cap for current SDK session if needed
ShadowApp.adminSql.disableSessionRowCap();
```

---

## Dart Types

### Core Types

```dart
// User
class AuthUser {
  final String id;
  final String email;
  final String role; // 'user' or 'admin'
  final DateTime createdAt;
}

// Document
class ShadowDocument {
  final String id;
  final String collectionId;
  final String ownerId;
  final Map<String, dynamic> data; // Your custom data
  final DateTime createdAt;
  final DateTime updatedAt;
}

// Media Upload Result
class MediaUploadResult {
  final String id;
  final int originalSize;
  final int compressedSize;
  final String compressionAlgo;
}

// Media Metadata
class MediaMetadata {
  final String id;
  final String uploaderId;
  final String filename;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;
}
```

### Exception Types

```dart
// Base exception
class ShadowAppException implements Exception {
  final String message;
  const ShadowAppException(this.message);
}

// Authentication failures
class AuthException extends ShadowAppException {
  const AuthException(String message) : super(message);
}

// Network/connectivity issues
class NetworkException extends ShadowAppException {
  const NetworkException(String message) : super(message);
}

// Document not found
class NotFoundException extends ShadowAppException {
  const NotFoundException(String message) : super(message);
}

// Permission denied
class PermissionException extends ShadowAppException {
  const PermissionException(String message) : super(message);
}

// Validation errors
class ValidationException extends ShadowAppException {
  const ValidationException(String message) : super(message);
}
```

---

## Error Handling

### Global Error Handling

```dart
class ErrorHandler {
  static void handleError(dynamic error, {String? context}) {
    if (error is AuthException) {
      print('🔒 Auth Error: ${error.message}');
      // Navigate to login
    } else if (error is NetworkException) {
      print('🌐 Network Error: ${error.message}');
      // Show retry dialog
    } else if (error is NotFoundException) {
      print('❌ Not Found: ${error.message}');
      // Show 404 message
    } else if (error is PermissionException) {
      print('🚫 Permission Denied: ${error.message}');
      // Show access denied message
    } else if (error is ValidationException) {
      print('⚠️  Validation Error: ${error.message}');
      // Show validation feedback
    } else {
      print('❗ Unknown Error in $context: $error');
      // Log to crash reporting service
    }
  }
}
```

### Widget-Level Error Handling

```dart
class ErrorBoundaryWidget extends StatelessWidget {
  final Widget child;

  const ErrorBoundaryWidget({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }

  static Widget buildErrorWidget(BuildContext context, dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'An error occurred',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
```

### Network Error Retry Pattern

```dart
Future<T> retryOnNetworkError<T>({
  required Future<T> Function() operation,
  int maxRetries = 3,
  Duration delayBetweenRetries = const Duration(seconds: 2),
}) async {
  int attempts = 0;

  while (attempts < maxRetries) {
    try {
      return await operation();
    } on NetworkException catch (e) {
      attempts++;
      if (attempts >= maxRetries) {
        rethrow;
      }
      print('Network error, retrying ($attempts/$maxRetries)...');
      await Future.delayed(delayBetweenRetries);
    }
  }

  throw NetworkException('Max retries exceeded');
}

// Usage:
final notes = await retryOnNetworkError(
  operation: () => ShadowApp.collection('notes').list(),
);
```

---

## State Management

### Using Provider

```dart
import 'package:provider/provider.dart';

class NotesProvider with ChangeNotifier {
  List<ShadowDocument> _notes = [];
  bool _isLoading = false;
  String? _error;

  List<ShadowDocument> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchNotes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notes = await ShadowApp.collection('notes').list();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(Map<String, dynamic> data) async {
    try {
      final newNote = await ShadowApp.collection('notes').create(data);
      _notes.add(newNote);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await ShadowApp.collection('notes').delete(noteId);
      _notes.removeWhere((note) => note.id == noteId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

// Setup in main.dart:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShadowApp.initialize(serverUrl: 'http://localhost:8080');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Use in  Widget:
class NotesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        if (notesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: notesProvider.notes.length,
          itemBuilder: (context, index) {
            final note = notesProvider.notes[index];
            return ListTile(
              title: Text(note.data['title'] ?? 'Untitled'),
              subtitle: Text(note.data['content'] ?? ''),
            );
          },
        );
      },
    );
  }
}
```

### Using Riverpod

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for notes
final notesProvider = FutureProvider<List<ShadowDocument>>((ref) async {
  return await ShadowApp.collection('notes').list();
});

// Provider for auth state
final authStateProvider = StateProvider<AuthUser?>((ref) {
  return ShadowApp.auth.currentUser;
});

// Use in Widget:
class NotesScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return notesAsync.when(
      data: (notes) => ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return ListTile(
            title: Text(note.data['title'] ?? 'Untitled'),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
```

### Using BLoC

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

// Events
abstract class NotesEvent {}
class LoadNotes extends NotesEvent {}
class AddNote extends NotesEvent {
  final Map<String, dynamic> data;
  AddNote(this.data);
}
class DeleteNote extends NotesEvent {
  final String noteId;
  DeleteNote(this.noteId);
}

// States
abstract class NotesState {}
class NotesInitial extends NotesState {}
class NotesLoading extends NotesState {}
class NotesLoaded extends NotesState {
  final List<ShadowDocument> notes;
  NotesLoaded(this.notes);
}
class NotesError extends NotesState {
  final String message;
  NotesError(this.message);
}

// BLoC
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc() : super(NotesInitial()) {
    on<LoadNotes>(_onLoadNotes);
    on<AddNote>(_onAddNote);
    on<DeleteNote>(_onDeleteNote);
  }

  Future<void> _onLoadNotes(LoadNotes event, Emitter<NotesState> emit) async {
    emit(NotesLoading());
    try {
      final notes = await ShadowApp.collection('notes').list();
      emit(NotesLoaded(notes));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _onAddNote(AddNote event, Emitter<NotesState> emit) async {
    try {
      await ShadowApp.collection('notes').create(event.data);
      add(LoadNotes()); // Reload
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _onDeleteNote(DeleteNote event, Emitter<NotesState> emit) async {
    try {
      await ShadowApp.collection('notes').delete(event.noteId);
      add(LoadNotes()); // Reload
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }
}

// Use in Widget:
class NotesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotesBloc, NotesState>(
      builder: (context, state) {
        if (state is NotesLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is NotesLoaded) {
          return ListView.builder(
            itemCount: state.notes.length,
            itemBuilder: (context, index) {
              final note = state.notes[index];
              return ListTile(
                title: Text(note.data['title'] ?? 'Untitled'),
              );
            },
          );
        } else if (state is NotesError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        return const SizedBox.shrink();
      },
    );
  }
}
```

---

## Best Practices

### 1. Initialize Once

✅ **Do:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShadowApp.initialize(serverUrl: '...');
  runApp(const MyApp());
}
```

❌ **Don't:**

```dart
// Multiple initializations cause conflicts
await ShadowApp.initialize(...);
await ShadowApp.initialize(...); // ERROR!
```

### 2. Handle Loading States

✅ **Do:**

```dart
Future<void> loadData() async {
  setState(() => _isLoading = true);
  try {
    final data = await ShadowApp.collection('notes').list();
    setState(() {
      _data = data;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}
```

❌ **Don't:**

```dart
// Assuming data is always available
final data = await ShadowApp.collection('notes').list();
// No loading state or error handling
```

### 3. Use Mounted Check

✅ **Do:**

```dart
Future<void> fetchData() async {
  final data = await ShadowApp.collection('notes').list();
  if (mounted) {
    setState(() => _notes = data);
  }
}
```

❌ **Don't:**

```dart
// Calling setState after widget disposal causes errors
Future<void> fetchData() async {
  final data = await ShadowApp.collection('notes').list();
  setState(() => _notes = data); // May error if widget unmounted
}
```

### 4. Dispose Controllers

✅ **Do:**

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

### 5. Validate User Input

✅ **Do:**

```dart
Future<void> createNote() async {
  if (_titleController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Title cannot be empty')),
    );
    return;
  }

  await ShadowApp.collection('notes').create({
    'title': _titleController.text,
  });
}
```

### 6. Use Const Constructors

✅ **Do:**

```dart
const Text('Hello');
const SizedBox(height: 16);
const CircularProgressIndicator();
```

Improves performance by reusing widget instances.

### 7. Handle Offline Scenarios

✅ **Do:**

```dart
try {
  final notes = await ShadowApp.collection('notes').list();
  setState(() => _notes = notes);
} on NetworkException catch (e) {
  // Show offline message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No network connection'),
      action: SnackBarAction(label: 'Retry', onPressed: loadNotes),
    ),
  );
}
```

---

## Operator Coordination

The Flutter SDK works against a backend that may now be administratively updated through the operator console.

Recommended app behavior:

- Show clear login errors and let users retry with a changed email if an operator updates their account.
- If login suddenly fails after a support interaction, prompt the user to verify whether their email or password was reset.
- Do not assume the email address used during signup is immutable.
- Treat admin report bundle export and email features as operator-only backend tooling, not as client SDK responsibilities.

## Comparison with React SDK

Both SDKs provide **identical features** but with different architectural approaches:

### File Count Comparison

| SDK             | Files   | Reason                                                        |
| --------------- | ------- | ------------------------------------------------------------- |
| **Flutter SDK** | 5 files | Dart types inline, service classes, simpler config            |
| **React SDK**   | 8 files | TypeScript types, React hooks, Context Provider, build config |

### Architecture Comparison

**Flutter SDK Philosophy:**

- Object-oriented service classes
- Singleton pattern with static methods (`ShadowApp.auth.login()`)
- Types live with implementation
- Dart's built-in type system

**React SDK Philosophy:**

- Separation of concerns (types, client, hooks, context)
- Functional programming with hooks
- Context API for dependency injection
- TypeScript for type safety

### Feature Parity

| Feature               | Flutter SDK          | React SDK     |
| --------------------- | -------------------- | ------------- |
| Authentication        | ✅                   | ✅            |
| CRUD Operations       | ✅                   | ✅            |
| Media Upload/Download | ✅                   | ✅            |
| Token Refresh         | ✅ Automatic         | ✅ Automatic  |
| Type Safety           | ✅ Dart              | ✅ TypeScript |
| State Management      | ✅ Built-in          | ✅ Hooks      |
| Offline Support       | ✅ SharedPreferences | ❌            |
| Progress Tracking     | ✅                   | ✅            |

### Code Comparison

**Flutter SDK:**

```dart
// Setup
await ShadowApp.initialize(serverUrl: '...');

// Usage
final notes = await ShadowApp.collection('notes').list();
final newNote = await ShadowApp.collection('notes').create({
  'title': 'My Note',
});
```

**React SDK:**

```tsx
// Setup
<ShadowAppProvider config={{ baseURL: "..." }}>
  <App />
</ShadowAppProvider>;

// Usage
const { documents, createDocument } = useDocuments(client, "notes");
await createDocument({ data: { title: "My Note" } });
```

### When to Use Each

**Use Flutter SDK when:**

- Building mobile apps (iOS/Android)
- Building desktop apps (Windows/Mac/Linux)
- Need offline-first capabilities
- Dart/Flutter is your primary framework
- Native performance is critical

**Use React SDK when:**

- Building web applications
- Working with React/Next.js/Remix
- Need browser-based file handling
- TypeScript is your primary language
- Web-only deployment

---

## Additional Resources

### Documentation

- [React SDK Guide](./REACT_SDK_GUIDE.md) - React SDK documentation
- [CLI Audit Report](./CLI_AUDIT_REPORT.md) - Backend CLI details
- [Architecture](./ARCHITECTURE.md) - Backend architecture overview
- [Operator Manual](./OPERATOR_MANUAL.md) - Server operation guide
- [Maintenance & Scaling](./MAINTENANCE_SCALING_GUIDE.md) - Deployment strategies

### Internal Documentation

For understanding how the SDK works internally:

- Read the source code in `flutter_sdk/lib/`
- All methods have detailed comments explaining backend communication
- Check `auth_service.dart` for JWT token management
- Review `crud_service.dart` for HTTP request patterns
- Inspect `media_service.dart` for compression algorithms

### Examples

See the complete example app in this guide (sections above) for a fully functional notes application with authentication, CRUD operations, and error handling.

### Support

For issues, questions, or contributions:

- **Repository:** Gracelium64/dartBackendServer
- **Branch:** devGrace (development)
- **Backend Version:** 0.1.0
- **SDK Version:** 0.1.0

---

**Guide Version:** 1.0  
**Last Updated:** March 8, 2026  
**Maintainer:** Shadow App Team
