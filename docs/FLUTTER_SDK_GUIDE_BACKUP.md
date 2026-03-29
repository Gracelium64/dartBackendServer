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
14. [Comparison with React SDK](#comparison-with-react-sdk)

---

## Overview

The Shadow App Flutter SDK is a Dart-native client library for integrating with the Shadow App Dart Backend Server. It provides a complete set of tools for modern Flutter applications including:

- 🔐 **Authentication** - JWT-based auth with automatic token refresh
- 📄 **Document CRUD** - Full create, read, update, delete operations
- 📁 **Media Handling** - File upload/download with compression
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
   - If match, generates JWT token (RS256 algorithm, 24h expiry)
   - Token is a signed, encrypted blob that proves your identity

3. **JWT Token**:

   ```
   eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyLWFiYzEyMyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsImV4cCI6MTYwMjM5NjU0N30.SflKxwRJSmYq...
   ```

   - **Header**: Algorithm (RS256)
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
                  // Open note editor
                },
              );
            },
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

class _CreateNoteDialog extends StatefulWidget {
  @override
  State<_CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<_CreateNoteDialog> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Note'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Note title'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
```

## Now What?

1. **Read [ARCHITECTURE.md](ARCHITECTURE.md)** to understand how the backend works internally
2. **Explore [OPERATOR_MANUAL.md](OPERATOR_MANUAL.md)** to learn how to run and monitor the server
3. **Check [MAINTENANCE_SCALING_GUIDE.md](MAINTENANCE_SCALING_GUIDE.md)** for deployment strategies

---

**Questions or issues?** Review the troubleshooting section in the Operator Manual or inspect server logs at `data/logs/`.
