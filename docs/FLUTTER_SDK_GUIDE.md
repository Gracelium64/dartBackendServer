# Shadow App Backend - Flutter SDK Guide

## Introduction

This guide teaches you how to integrate the Shadow App Backend into your Flutter app. The SDK provides simple, intuitive methods for authentication, CRUD operations, and media handling—similar to Firebase, but with complete backend transparency and learning value.

## What is Shadow App Backend?

Shadow App Backend is a Dart backend server that provides:
- **Authentication**: Email/password signup and login with JWT tokens
- **Database**: Store and retrieve JSON documents in collections
- **Media Storage**: Upload/download and compress images, videos, files
- **Access Control**: Define read/write rules per collection
- **Live Logging**: Audit trail of all database actions

Unlike Firebase, this backend is:
- **Open source and transparent**: You can inspect and modify the code
- **Educational**: Extensive comments explain backend internals to Flutter developers
- **Simple syntax**: CRUD commands use obvious, readable methods

## Installation

### 1. Add the SDK to your pubspec.yaml

In your Flutter project root, edit `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shadow_app_backend:
    path: ../dartBackendServer/flutter_sdk
```

Then fetch packages:

```bash
flutter pub get
```

### 2. Import in your Dart files

```dart
import 'package:shadow_app_backend/shadow_app.dart';
```

## Quick Start

### Initialize the SDK

In your app's `main()` function or at app startup:

```dart
import 'package:shadow_app_backend/shadow_app.dart';

void main() {
  // Initialize SDK with server URL
  ShadowApp.initialize(
    serverUrl: 'http://192.168.1.100:8080',  // Your backend server URL
    // Optional: offline fallback (stores locally until sync)
    enableOfflineMode: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: LoginScreen(),
    );
  }
}
```

### Authenticate (Signup & Login)

#### Sign Up a New User

```dart
import 'package:shadow_app_backend/shadow_app.dart';

Future<void> signupUser(String email, String password) async {
  try {
    final user = await ShadowApp.auth.signup(
      email: email,
      password: password,
    );
    print('Signup successful! User ID: ${user.id}');
    // Token automatically stored; ready to use
  } catch (e) {
    print('Signup failed: $e');
  }
}
```

#### Log In

```dart
Future<void> loginUser(String email, String password) async {
  try {
    final user = await ShadowApp.auth.login(
      email: email,
      password: password,
    );
    print('Login successful! Welcome ${user.email}');
    // Token automatically stored for future requests
  } catch (e) {
    print('Login failed: $e');
  }
}
```

#### Log Out

```dart
Future<void> logoutUser() async {
  await ShadowApp.auth.logout();
  print('Logged out');
}
```

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
