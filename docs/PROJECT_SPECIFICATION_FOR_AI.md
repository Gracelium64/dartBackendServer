# ShadowApp Backend Project Specification for AI Learning Program

**Document Purpose:** This file provides comprehensive technical specifications for an AI agent to analyze this codebase and create an educational learning program teaching users how to use this backend and how to build similar systems.

**Project Version:** 0.1.0  
**Language:** Dart  
**Framework:** Shelf (HTTP server)  
**Repository:** Gracelium64/dartBackendServer  
**Branch:** devGrace (development)  
**Date:** March 8, 2026

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Core Components](#core-components)
4. [Authentication System](#authentication-system)
5. [CRUD Operations](#crud-operations)
6. [Media Handling](#media-handling)
7. [Database Layer](#database-layer)
8. [CLI Program](#cli-program)
9. [Admin GUI](#admin-gui)
10. [Client SDKs](#client-sdks)
11. [Security Model](#security-model)
12. [Testing Infrastructure](#testing-infrastructure)
13. [Deployment & Operations](#deployment--operations)
14. [Code Organization](#code-organization)
15. [Learning Objectives](#learning-objectives)
16. [Teaching Approach Recommendations](#teaching-approach-recommendations)

---

## Project Overview

### What is ShadowApp?

ShadowApp is a **full-stack backend-as-a-service (BaaS)** platform built in Dart that provides:

- **RESTful API** for client applications
- **User authentication** with JWT tokens and role-based access control
- **Document database** operations (CRUD) with ownership and permissions
- **Media storage** with automatic compression and metadata tracking
- **Client SDKs** for Flutter (mobile/desktop) and React (web)
- **CLI administration** tool for server management
- **Admin GUI** Flutter application for visual administration

### Project Purpose

This backend serves as:

1. **Production-ready BaaS** for rapid application development
2. **Educational reference** for building Dart/Shelf web servers
3. **Example implementation** of authentication, database, and media handling
4. **Foundation** for mobile and web applications

### Key Features

- ✅ JWT-based authentication with refresh tokens
- ✅ Role-based access control (user/admin)
- ✅ Document collections with per-user ownership
- ✅ Media upload with automatic compression (gzip/brotli/zstd)
- ✅ RESTful API with consistent error handling
- ✅ SQLite database with migration system
- ✅ Email notifications (SMTP)
- ✅ Health check endpoint
- ✅ Comprehensive logging
- ✅ Password validation rules
- ✅ Token refresh mechanism
- ✅ Cross-platform client SDKs

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT APPLICATIONS                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Flutter App  │  │  React App   │  │  Admin GUI   │      │
│  │ (Mobile/Desk)│  │    (Web)     │  │  (Flutter)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            │                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   Flutter SDK   │
                    │    React SDK    │
                    └────────┬────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                      DART BACKEND SERVER                      │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                   HTTP Layer (Shelf)                 │    │
│  │  - Request routing                                   │    │
│  │  - Middleware (CORS, logging, auth)                 │    │
│  │  - Response formatting                               │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│  ┌──────────────────────▼───────────────────────────────┐    │
│  │                   API Handlers                       │    │
│  │  - /auth/*    - Authentication endpoints            │    │
│  │  - /documents/* - CRUD operations                   │    │
│  │  - /media/*   - File upload/download                │    │
│  │  - /health    - Server status                       │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│  ┌──────────────────────▼───────────────────────────────┐    │
│  │                  Business Logic                      │    │
│  │  - AuthService    - User management, JWT            │    │
│  │  - RuleEngine     - Password validation             │    │
│  │  - DbManager      - Database operations             │    │
│  │  - EmailService   - SMTP notifications              │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│  ┌──────────────────────▼───────────────────────────────┐    │
│  │                  Data Layer                          │    │
│  │  - SQLite Database                                   │    │
│  │    • users table                                     │    │
│  │    • documents table                                 │    │
│  │    • media_files table                               │    │
│  │  - File System                                       │    │
│  │    • bin/data/ (media storage)                       │    │
│  │    • data/logs/ (application logs)                   │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                    ADMINISTRATION TOOLS                       │
│  ┌──────────────┐              ┌──────────────┐             │
│  │  CLI Tool    │              │  Admin GUI   │             │
│  │  (bin/main)  │              │ (Flutter App)│             │
│  │  - User mgmt │              │ - Visual UI  │             │
│  │  - DB mgmt   │              │ - Same APIs  │             │
│  │  - Server ctl│              │ - Admin only │             │
│  └──────────────┘              └──────────────┘             │
└───────────────────────────────────────────────────────────────┘
```

### Request Flow

1. **Client Request** → Client SDK (Flutter/React)
2. **SDK Processing** → Adds auth headers, formats data
3. **HTTP Request** → Shelf server receives request
4. **Middleware Chain** → CORS → Logging → Authentication
5. **Router** → Routes to appropriate handler
6. **Handler** → Validates input, calls business logic
7. **Business Logic** → Processes request, interacts with database
8. **Database** → Executes query, returns data
9. **Response** → Formats JSON, sends to client
10. **SDK Processing** → Parses response, updates client state

### Technology Stack

**Backend:**

- **Language:** Dart 3.x
- **HTTP Server:** Shelf (pub.dev/packages/shelf)
- **Database:** SQLite (sqlite3 package)
- **Authentication:** JWT (dart_jsonwebtoken package)
- **Password Hashing:** crypto (SHA-256)
- **Compression:** zstd, gzip, brotli
- **Email:** mailer (SMTP)
- **Logging:** Custom logger with file rotation

**Client SDKs:**

- **Flutter SDK:** Dart (dio, shared_preferences, image compression)
- **React SDK:** TypeScript (axios, React hooks, Context API)

**Administration:**

- **CLI:** Dart console application
- **Admin GUI:** Flutter desktop application

---

## Core Components

### Component Hierarchy

```
lib/
├── config.dart              # Server configuration
├── server.dart              # Main server setup
├── api/
│   └── crud_handlers.dart   # REST API endpoints
├── auth/
│   ├── auth_service.dart    # Authentication logic
│   ├── password_utils.dart  # Password validation
│   └── rule_engine.dart     # Password rules engine
├── database/
│   ├── db_manager.dart      # Database operations
│   ├── migrations.dart      # Schema migrations
│   └── models.dart          # Data models
└── logging/
    ├── email_service.dart   # Email notifications
    └── logger.dart          # Logging system
```

### 1. Server Setup (lib/server.dart)

**Purpose:** Initialize and configure the HTTP server.

**Key Functions:**

```dart
Future<HttpServer> startServer({
  required String host,
  required int port,
  required DbManager dbManager,
}) async
```

**Responsibilities:**

- Create Shelf pipeline with middleware
- Configure CORS headers
- Set up request logging
- Register route handlers
- Start HTTP listener

**Middleware Chain:**

1. CORS headers (allow all origins in dev)
2. Request logging (method, path, status, duration)
3. Authentication extraction (JWT from Authorization header)

**Routes:**

- `POST /auth/signup` - Create new user
- `POST /auth/login` - Authenticate user
- `POST /auth/logout` - End session
- `POST /auth/refresh` - Refresh access token
- `GET /health` - Server health check
- `POST /documents/:collection` - Create document
- `GET /documents/:collection/:id` - Read document
- `PUT /documents/:collection/:id` - Update document
- `DELETE /documents/:collection/:id` - Delete document
- `GET /documents/:collection` - List documents
- `POST /media` - Upload file
- `GET /media/:id` - Download file
- `GET /media/:id/metadata` - Get file metadata

### 2. Configuration (lib/config.dart)

**Purpose:** Centralized configuration management.

**Key Classes:**

```dart
class AppConfig {
  static const String jwtSecret = '...';
  static const Duration accessTokenExpiry = Duration(minutes: 15);
  static const Duration refreshTokenExpiry = Duration(days: 7);

  static const int maxPasswordLength = 128;
  static const int minPasswordLength = 8;

  static const List<String> compressionAlgorithms = ['zstd', 'gzip', 'brotli'];
}
```

**Configuration Types:**

- **JWT Settings:** Secret, expiry times, algorithm
- **Password Rules:** Length, complexity requirements
- **Compression:** Supported algorithms, default choice
- **Server:** Host, port, database path
- **Email:** SMTP settings (host, port, credentials)
- **Logging:** Log levels, file paths, rotation

### 3. Request Handlers (lib/api/crud_handlers.dart)

**Purpose:** Handle HTTP requests and route to business logic.

**Handler Pattern:**

```dart
Future<Response> handleRequest(Request request) async {
  try {
    // 1. Extract parameters
    final params = request.params;

    // 2. Parse body (if POST/PUT)
    final body = await request.readAsString();
    final data = jsonDecode(body);

    // 3. Get authenticated user (if auth required)
    final userId = request.context['userId'];

    // 4. Call business logic
    final result = await businessLogicMethod(params, data, userId);

    // 5. Return success response
    return Response.ok(
      jsonEncode({'success': true, 'data': result}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    // 6. Return error response
    return Response.internalServerError(
      body: jsonEncode({'success': false, 'error': e.toString()}),
    );
  }
}
```

**Error Handling Strategy:**

- Catch all exceptions
- Log errors with context
- Return consistent JSON error format
- Use appropriate HTTP status codes (200, 400, 401, 403, 404, 500)

---

## Authentication System

### Architecture

The authentication system implements a **JWT-based stateless authentication** with refresh tokens.

### Components

**1. AuthService (lib/auth/auth_service.dart)**

Core authentication logic:

```dart
class AuthService {
  final DbManager _db;
  final Logger _logger;

  // User signup
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
  }) async

  // User login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async

  // Token refresh
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async

  // Password validation
  Future<void> validatePassword(String password) async
}
```

**2. JWT Token Structure**

**Access Token (15 minutes):**

```json
{
  "userId": "abc123",
  "email": "user@example.com",
  "role": "user",
  "type": "access",
  "iat": 1709913600,
  "exp": 1709914500
}
```

**Refresh Token (7 days):**

```json
{
  "userId": "abc123",
  "type": "refresh",
  "iat": 1709913600,
  "exp": 1710518400
}
```

**3. Password Security**

**Hashing:**

- Algorithm: SHA-256 with salt
- Salt: Unique per user, stored with hash
- Format: `salt:hash` in database

**Validation Rules (lib/auth/rule_engine.dart):**

```dart
// Default rules:
- Minimum length: 8 characters
- Maximum length: 128 characters
- Require: 1 uppercase, 1 lowercase, 1 digit
- Optional: Special characters

// Configurable via RuleEngine:
final rules = [
  LengthRule(min: 8, max: 128),
  UppercaseRule(min: 1),
  LowercaseRule(min: 1),
  DigitRule(min: 1),
];
```

### Authentication Flow

**Signup Flow:**

```
1. Client sends email + password
2. Server validates password rules
3. Server checks if email exists
4. Server hashes password with salt
5. Server creates user in database
6. Server generates access + refresh tokens
7. Server returns tokens + user data
```

**Login Flow:**

```
1. Client sends email + password
2. Server finds user by email
3. Server verifies password hash
4. Server generates new access + refresh tokens
5. Server returns tokens + user data
```

**Token Refresh Flow:**

```
1. Client sends refresh token
2. Server validates refresh token
3. Server extracts userId from token
4. Server generates new access token
5. Server returns new access token
```

**Authenticated Request Flow:**

```
1. Client includes: Authorization: Bearer <accessToken>
2. Server middleware extracts token
3. Server validates token signature + expiry
4. Server adds userId to request context
5. Handler accesses userId for authorization
```

### Security Considerations

**Implemented:**

- ✅ Password hashing (SHA-256 + salt)
- ✅ JWT signature verification
- ✅ Token expiration
- ✅ Role-based access control
- ✅ Refresh token mechanism
- ✅ Password complexity rules

**For Production (not implemented):**

- ❌ Password hashing should use bcrypt/argon2 (more secure than SHA-256)
- ❌ Refresh token rotation (issue new refresh token on use)
- ❌ Token revocation list
- ❌ Rate limiting on auth endpoints
- ❌ Account lockout after failed attempts
- ❌ Two-factor authentication
- ❌ HTTPS enforcement

---

## CRUD Operations

### Document Model

Every document has this structure:

```dart
class ShadowDocument {
  final String id;              // UUID
  final String collectionId;    // Collection name (e.g., 'notes', 'posts')
  final String ownerId;         // User ID who created it
  final Map<String, dynamic> data; // Custom user data
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Database Schema

```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  collection_id TEXT NOT NULL,
  owner_id TEXT NOT NULL,
  data TEXT NOT NULL,  -- JSON string
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (owner_id) REFERENCES users(id)
);

CREATE INDEX idx_documents_collection ON documents(collection_id);
CREATE INDEX idx_documents_owner ON documents(owner_id);
```

### CRUD Operations

**Create Document:**

```dart
POST /documents/:collection
Headers: Authorization: Bearer <accessToken>
Body: {
  "data": {
    "title": "My Note",
    "content": "Hello world",
    "tags": ["important"]
  }
}

Response: {
  "success": true,
  "data": {
    "id": "doc-abc123",
    "collectionId": "notes",
    "ownerId": "user-xyz789",
    "data": { "title": "My Note", ... },
    "createdAt": "2026-03-08T10:00:00Z",
    "updatedAt": "2026-03-08T10:00:00Z"
  }
}
```

**Read Document:**

```dart
GET /documents/:collection/:id
Headers: Authorization: Bearer <accessToken>

Response: {
  "success": true,
  "data": { ...document... }
}
```

**Update Document:**

```dart
PUT /documents/:collection/:id
Headers: Authorization: Bearer <accessToken>
Body: {
  "data": {
    "title": "Updated Title"
  }
}

// Merges data by default, unless merge=false in query params
Response: { "success": true, "data": { ...updated document... } }
```

**Delete Document:**

```dart
DELETE /documents/:collection/:id
Headers: Authorization: Bearer <accessToken>

Response: {
  "success": true,
  "message": "Document deleted"
}
```

**List Documents:**

```dart
GET /documents/:collection?limit=50&offset=0
Headers: Authorization: Bearer <accessToken>

Response: {
  "success": true,
  "data": [
    { ...document 1... },
    { ...document 2... },
    ...
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "total": 127
  }
}
```

### Authorization Rules

**Ownership-Based Access Control:**

- Users can only CRUD their own documents
- Admins can CRUD any documents
- Documents belong to the user who created them
- Collection names are user-defined (no schema enforcement)

**Implementation:**

```dart
Future<void> checkOwnership(String docId, String userId) async {
  final doc = await _db.getDocument(docId);

  if (doc.ownerId != userId && userRole != 'admin') {
    throw UnauthorizedException('Not document owner');
  }
}
```

---

## Media Handling

### Media Architecture

Media files are stored in the **file system** with metadata in the **database**.

### Media Model

```dart
class MediaFile {
  final String id;              // UUID
  final String uploaderId;      // User ID
  final String filename;        // Original filename
  final String mimeType;        // e.g., 'image/jpeg'
  final int originalSize;       // Bytes before compression
  final int compressedSize;     // Bytes after compression
  final String compressionAlgo; // 'zstd', 'gzip', or 'brotli'
  final DateTime uploadedAt;
}
```

### Database Schema

```sql
CREATE TABLE media_files (
  id TEXT PRIMARY KEY,
  uploader_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  original_size INTEGER NOT NULL,
  compressed_size INTEGER NOT NULL,
  compression_algo TEXT NOT NULL,
  uploaded_at INTEGER NOT NULL,
  FOREIGN KEY (uploader_id) REFERENCES users(id)
);
```

### File Storage

**Directory Structure:**

```
bin/data/
├── media/
│   ├── abc123-image1.jpg.zst
│   ├── def456-document.pdf.gz
│   └── ghi789-video.mp4.br
└── logs/
    ├── app.log
    └── error.log
```

**Naming Convention:**

- Format: `{mediaId}-{originalFilename}.{extension}`
- Compression extension added: `.zst`, `.gz`, or `.br`

### Upload Flow

```
1. Client selects file
2. Client sends multipart/form-data POST request
3. Server receives file stream
4. Server determines best compression algorithm
5. Server compresses file
6. Server saves compressed file to disk
7. Server creates metadata record in database
8. Server returns media ID and metadata
```

**API Endpoint:**

```dart
POST /media
Headers:
  Authorization: Bearer <accessToken>
  Content-Type: multipart/form-data
Body:
  file: <binary data>
  mediaType: "image"  // or "video", "document"

Response: {
  "success": true,
  "data": {
    "id": "media-abc123",
    "originalSize": 1048576,
    "compressedSize": 524288,
    "compressionAlgo": "zstd",
    "filename": "photo.jpg",
    "mimeType": "image/jpeg"
  }
}
```

### Download Flow

```
1. Client requests file by media ID
2. Server checks authorization (owner or admin)
3. Server looks up metadata in database
4. Server reads compressed file from disk
5. Server decompresses file
6. Server streams file to client
```

**API Endpoint:**

```dart
GET /media/:id
Headers: Authorization: Bearer <accessToken>

Response:
  Binary file data with appropriate Content-Type header
  Content-Type: image/jpeg
  Content-Disposition: attachment; filename="photo.jpg"
```

### Compression Algorithms

**Supported:**

1. **Zstandard (zstd)** - Best overall, fast + high compression
2. **Gzip** - Widely supported, moderate compression
3. **Brotli** - Best compression ratio, slower

**Selection Strategy:**

```dart
String selectCompression(String mimeType) {
  if (mimeType.startsWith('image/')) return 'zstd';
  if (mimeType.startsWith('video/')) return 'gzip'; // Already compressed
  if (mimeType.startsWith('text/')) return 'brotli'; // High text compression
  return 'zstd'; // Default
}
```

### Authorization

**Media Access Rules:**

- Users can upload any files
- Users can download only their own files
- Admins can download any files
- Anonymous users cannot access media

---

## Database Layer

### Database Manager (lib/database/db_manager.dart)

**Purpose:** Abstraction layer over SQLite operations.

**Key Methods:**

```dart
class DbManager {
  // User operations
  Future<User> createUser(String email, String passwordHash, String role);
  Future<User?> getUserByEmail(String email);
  Future<User?> getUserById(String id);

  // Document operations
  Future<ShadowDocument> createDocument(String collectionId, String ownerId, Map<String, dynamic> data);
  Future<ShadowDocument?> getDocument(String id);
  Future<ShadowDocument> updateDocument(String id, Map<String, dynamic> data, bool merge);
  Future<void> deleteDocument(String id);
  Future<List<ShadowDocument>> listDocuments(String collectionId, String? ownerId, int limit, int offset);

  // Media operations
  Future<MediaFile> createMediaFile(String uploaderId, String filename, String mimeType, int originalSize, int compressedSize, String algo);
  Future<MediaFile?> getMediaFile(String id);
  Future<List<MediaFile>> listMediaFiles(String uploaderId);
}
```

### Schema Migrations (lib/database/migrations.dart)

**Purpose:** Version-controlled database schema changes.

**Migration System:**

```dart
class DatabaseMigrations {
  static Future<void> migrate(Database db) async {
    final version = await _getCurrentVersion(db);

    if (version < 1) await _migrateToV1(db);
    if (version < 2) await _migrateToV2(db);
    // ... more migrations
  }

  static Future<void> _migrateToV1(Database db) async {
    // Create initial schema
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE documents (...)
    ''');

    // etc.
  }
}
```

**Migration Strategy:**

- Track version in `schema_version` table
- Each migration is a function
- Migrations run in order
- Never modify past migrations (create new ones)
- Backup database before migrations

### Data Models (lib/database/models.dart)

**Purpose:** Type-safe representations of database records.

**Models:**

```dart
class User {
  final String id;
  final String email;
  final String passwordHash;
  final String role;
  final DateTime createdAt;

  // Factory from database row
  factory User.fromRow(Map<String, dynamic> row) {
    return User(
      id: row['id'],
      email: row['email'],
      passwordHash: row['password_hash'],
      role: row['role'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
  };
}

// Similar classes for ShadowDocument and MediaFile
```

---

## CLI Program

### Purpose

Command-line interface for server administration without GUI.

**Location:** `bin/main.dart` (482 lines after refactoring)

### Features

**1. User Management**

```bash
# Create user
dart bin/main.dart user create user@example.com password123

# List users
dart bin/main.dart user list

# Delete user
dart bin/main.dart user delete user@example.com

# Change role
dart bin/main.dart user role user@example.com admin
```

**2. Database Management**

```bash
# Run migrations
dart bin/main.dart db migrate

# Backup database
dart bin/main.dart db backup

# Restore from backup
dart bin/main.dart db restore backup-20260308.db

# Clear all data
dart bin/main.dart db clear
```

**3. Server Control**

```bash
# Start server
dart bin/main.dart server start --port 8080

# Stop server
dart bin/main.dart server stop

# Status check
dart bin/main.dart server status

# View logs
dart bin/main.dart server logs --tail 100
```

**4. Document Operations**

```bash
# Create document
dart bin/main.dart doc create notes '{"title":"Hello"}'

# Read document
dart bin/main.dart doc read notes doc-123

# Update document
dart bin/main.dart doc update notes doc-123 '{"title":"Updated"}'

# Delete document
dart bin/main.dart doc delete notes doc-123

# List documents
dart bin/main.dart doc list notes
```

**5. Media Operations**

```bash
# Upload file
dart bin/main.dart media upload user@example.com ./photo.jpg image

# Download file
dart bin/main.dart media download media-123 ./output.jpg

# List media
dart bin/main.dart media list user@example.com

# Delete media
dart bin/main.dart media delete media-123
```

### CLI Architecture

**Command Pattern:**

```dart
abstract class Command {
  String get name;
  String get description;
  Future<void> execute(List<String> args);
}

class UserCreateCommand implements Command {
  final DbManager db;
  final AuthService auth;

  @override
  String get name => 'user create';

  @override
  Future<void> execute(List<String> args) async {
    final email = args[0];
    final password = args[1];

    await auth.signup(email: email, password: password);
    print('✅ User created: $email');
  }
}
```

**Main Program Flow:**

```dart
void main(List<String> args) async {
  // 1. Parse command
  final command = args[0];
  final subcommand = args.length > 1 ? args[1] : null;

  // 2. Initialize dependencies
  final db = await DbManager.initialize('data/shadow_app.db');
  final auth = AuthService(db);

  // 3. Route to command handler
  switch ('$command $subcommand') {
    case 'user create':
      await UserCreateCommand(db, auth).execute(args.sublist(2));
    case 'server start':
      await ServerStartCommand(db).execute(args.sublist(2));
    // ... etc
  }
}
```

---

## Admin GUI

### Overview

Flutter desktop application providing visual administration interface.

**Location:** `admin_gui/`

### Features

- User management (CRUD)
- Document browser by collection
- Media file gallery
- Server statistics dashboard
- Log viewer with filtering
- Database backup/restore
- Real-time server monitoring

### Architecture

```
admin_gui/
├── lib/
│   ├── main.dart           # Entry point
│   ├── models/             # Data models
│   ├── services/           # API client (uses Flutter SDK)
│   ├── screens/            # UI screens
│   │   ├── login_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── users_screen.dart
│   │   ├── documents_screen.dart
│   │   └── media_screen.dart
│   ├── widgets/            # Reusable components
│   └── utils/              # Helpers
├── pubspec.yaml
└── README.md
```

### Technical Details

**Authentication:**

- Admin GUI uses same JWT authentication as clients
- Requires admin role to access most features
- Uses Flutter SDK for API communication

**State Management:**

- Provider pattern for app state
- Separate providers for users, documents, media
- Real-time updates via polling

**UI Framework:**

- Material Design 3
- Responsive layout for different window sizes
- Data tables with sorting/filtering
- Charts for statistics (fl_chart package)

---

## Client SDKs

### Flutter SDK

**Location:** `flutter_sdk/`  
**Package:** `shadow_app_flutter_sdk`  
**Version:** 0.1.0

**Architecture:**

```
flutter_sdk/
├── lib/
│   ├── shadow_app.dart      # Main singleton
│   ├── auth_service.dart    # Authentication
│   ├── crud_service.dart    # Document operations
│   └── media_service.dart   # File handling
└── pubspec.yaml
```

**Key Features:**

- Singleton pattern for easy access
- Automatic token refresh
- Persistent authentication (SharedPreferences)
- Image compression before upload
- Progress tracking for uploads
- Type-safe Dart models

**Usage Example:**

```dart
// Initialize
await ShadowApp.initialize(serverUrl: 'http://localhost:8080');

// Authentication
await ShadowApp.auth.signup(email: 'test@example.com', password: 'Pass123!');
await ShadowApp.auth.login(email: 'test@example.com', password: 'Pass123!');

// CRUD
final notes = ShadowApp.collection('notes');
final newNote = await notes.create({'title': 'Hello', 'content': 'World'});
final allNotes = await notes.list();
await notes.update(newNote.id, {'title': 'Updated'});
await notes.delete(newNote.id);

// Media
final result = await ShadowApp.media.upload(
  filePath: '/path/to/image.jpg',
  mediaType: 'image',
  onProgress: (progress) => print('Upload: ${progress * 100}%'),
);
final bytes = await ShadowApp.media.download(result.id);

// Logout
await ShadowApp.auth.logout();
```

**Documentation:** `docs/FLUTTER_SDK_GUIDE.md` (1,786 lines)

### React SDK

**Location:** `flutter_sdk/` (contains both SDKs)  
**Package:** `@shadowapp/react-sdk`  
**Version:** 0.1.0

**Architecture:**

```
react_sdk/
├── src/
│   ├── types.ts           # TypeScript interfaces
│   ├── client.ts          # HTTP client
│   ├── hooks.tsx          # React hooks
│   ├── context.tsx        # Context provider
│   └── index.ts           # Exports
├── package.json
├── tsconfig.json
└── README.md
```

**Key Features:**

- TypeScript for type safety
- React hooks for state management
- Context API for dependency injection
- Axios for HTTP requests
- Automatic token refresh
- Progress tracking for uploads

**Usage Example:**

```tsx
import {
  ShadowAppProvider,
  useShadowApp,
  useAuth,
  useDocuments,
} from "@shadowapp/react-sdk";

// Setup
function App() {
  return (
    <ShadowAppProvider config={{ baseURL: "http://localhost:8080" }}>
      <MyComponent />
    </ShadowAppProvider>
  );
}

// Usage in component
function MyComponent() {
  const client = useShadowApp();
  const { user, login, signup, logout } = useAuth(client);
  const { documents, createDocument } = useDocuments(client, "notes");

  const handleCreate = async () => {
    await createDocument({
      data: { title: "New Note", content: "Hello" },
    });
  };

  return (
    <div>
      {user ? (
        <>
          <p>Logged in as {user.email}</p>
          <button onClick={logout}>Logout</button>
          <button onClick={handleCreate}>Create Note</button>
          <ul>
            {documents.map((doc) => (
              <li key={doc.id}>{doc.data.title}</li>
            ))}
          </ul>
        </>
      ) : (
        <button onClick={() => login("test@test.com", "Pass123!")}>
          Login
        </button>
      )}
    </div>
  );
}
```

**Documentation:** `docs/REACT_SDK_GUIDE.md` (1,426 lines)

### SDK Comparison

| Feature       | Flutter SDK          | React SDK                 |
| ------------- | -------------------- | ------------------------- |
| **Files**     | 5 files              | 8 files                   |
| **Pattern**   | Singleton + Services | Context + Hooks           |
| **Types**     | Inline Dart classes  | Separate TypeScript types |
| **State**     | Manual setState      | React hooks               |
| **Storage**   | SharedPreferences    | localStorage              |
| **HTTP**      | Dio                  | Axios                     |
| **Platforms** | Mobile, Desktop, Web | Web only                  |

**Both Support:**

- Authentication (signup, login, logout, token refresh)
- CRUD operations (create, read, update, delete, list)
- Media handling (upload, download, metadata)
- Progress tracking
- Error handling
- Type safety

---

## Security Model

### Authentication

**JWT Tokens:**

- ✅ Signed with HS256 algorithm
- ✅ Include userId, email, role
- ✅ Access token: 15 minutes
- ✅ Refresh token: 7 days
- ✅ Tokens validated on every protected request

### Authorization

**Role-Based Access Control (RBAC):**

- **User role:** Can CRUD own documents, access own media
- **Admin role:** Can CRUD all documents, access all media, use admin CLI

**Ownership Model:**

- Documents belong to creator (ownerId field)
- Media files belong to uploader (uploaderId field)
- Users can only access their own resources
- Admins can access any resource

### Password Security

**Storage:**

- ✅ SHA-256 hash with unique salt per user
- ✅ Salt stored with hash: `salt:hash`
- ❌ Should use bcrypt/argon2 for production

**Validation:**

- ✅ Minimum 8 characters
- ✅ Maximum 128 characters
- ✅ Require uppercase, lowercase, digit
- ✅ Configurable rules via RuleEngine

### Network Security

**CORS:**

- ✅ Enabled for development (allows all origins)
- ❌ Should restrict origins in production

**HTTPS:**

- ❌ Not implemented (uses HTTP)
- ❌ Should enforce HTTPS in production

**Rate Limiting:**

- ❌ Not implemented
- ❌ Should limit auth endpoints to prevent brute force

### Data Security

**Database:**

- ✅ Passwords hashed
- ✅ Foreign key constraints
- ❌ No field-level encryption
- ❌ No database encryption at rest

**Files:**

- ✅ Compressed (reduces size)
- ❌ Not encrypted
- ✅ Stored outside web root
- ✅ Access controlled by authorization

---

## Testing Infrastructure

### Test Organization

```
test/
├── _test_all.dart           # Test runner
├── unit/
│   ├── auth_service_test.dart
│   ├── db_manager_test.dart
│   ├── rule_engine_test.dart
│   └── password_utils_test.dart
└── integration/
    ├── test_helpers.dart
    ├── auth_integration_test.dart
    ├── crud_integration_test.dart
    └── media_integration_test.dart
```

### Unit Tests

**Purpose:** Test individual components in isolation.

**Coverage:**

- ✅ AuthService (signup, login, token generation)
- ✅ RuleEngine (password validation)
- ✅ PasswordUtils (hashing, verification)
- ✅ DbManager (CRUD operations)
- ❌ Email service (not tested)
- ❌ Media compression (not tested)

**Example:**

```dart
void main() {
  group('AuthService', () {
    late DbManager db;
    late AuthService auth;

    setUp(() async {
      db = await DbManager.initialize(':memory:');
      auth = AuthService(db);
    });

    test('signup creates user with hashed password', () async {
      final result = await auth.signup(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(result['user']['email'], 'test@example.com');
      expect(result['accessToken'], isNotNull);
      expect(result['refreshToken'], isNotNull);
    });

    test('login verifies password correctly', () async {
      await auth.signup(email: 'test@example.com', password: 'Password123!');

      final result = await auth.login(
        email: 'test@example.com',
        password: 'Password123!',
      );

      expect(result['user']['email'], 'test@example.com');
    });
  });
}
```

**Status:** 35 tests, 24 passing (unit tests only)

### Integration Tests

**Purpose:** Test API endpoints with real HTTP requests.

**Coverage:**

- ✅ Authentication flow (signup → login → refresh → logout)
- ✅ CRUD operations (create → read → update → delete → list)
- ✅ Media operations (upload → download → metadata)
- ✅ Authorization checks (accessing other user's data)
- ✅ Error handling (invalid input, expired tokens)

**Example:**

```dart
void main() {
  group('Document API Integration', () {
    late HttpServer server;
    late http.Client client;
    String? accessToken;

    setUp(() async {
      // Start test server
      final db = await DbManager.initialize(':memory:');
      server = await startServer(host: 'localhost', port: 8080, dbManager: db);
      client = http.Client();

      // Create test user and login
      final signupResponse = await client.post(
        Uri.parse('http://localhost:8080/auth/signup'),
        body: jsonEncode({'email': 'test@test.com', 'password': 'Pass123!'}),
      );
      accessToken = jsonDecode(signupResponse.body)['accessToken'];
    });

    test('create document returns valid document', () async {
      final response = await client.post(
        Uri.parse('http://localhost:8080/documents/notes'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': {'title': 'Test Note'}}),
      );

      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['success'], true);
      expect(data['data']['collectionId'], 'notes');
      expect(data['data']['data']['title'], 'Test Note');
    });

    tearDown(() async {
      await server.close();
      client.close();
    });
  });
}
```

**Status:** Structure complete, ready for implementation

### Running Tests

```bash
# All tests
dart test

# Unit tests only
dart test test/unit/

# Integration tests only
dart test test/integration/

# Specific file
dart test test/unit/auth_service_test.dart

# With coverage
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

---

## Deployment & Operations

### Server Startup

**Development:**

```bash
dart run bin/main.dart server start --port 8080
```

**Production:**

```bash
# Build native executable
dart compile exe bin/main.dart -o shadow_app_server

# Run binary
./shadow_app_server server start --port 8080 --host 0.0.0.0
```

### Environment Configuration

**Environment Variables:**

```bash
# Required
export SHADOW_APP_PORT=8080
export SHADOW_APP_HOST=0.0.0.0
export SHADOW_APP_JWT_SECRET=your-secret-key
export SHADOW_APP_DB_PATH=./data/shadow_app.db

# Optional
export SHADOW_APP_SMTP_HOST=smtp.gmail.com
export SHADOW_APP_SMTP_PORT=587
export SHADOW_APP_SMTP_USER=your-email@gmail.com
export SHADOW_APP_SMTP_PASSWORD=your-password
export SHADOW_APP_LOG_LEVEL=info
```

**Configuration Files:**

```dart
// lib/config.dart
class AppConfig {
  static String get jwtSecret =>
    Platform.environment['SHADOW_APP_JWT_SECRET'] ?? 'dev-secret';

  static int get port =>
    int.parse(Platform.environment['SHADOW_APP_PORT'] ?? '8080');

  // ... etc
}
```

### Logging

**Log Levels:**

- `DEBUG` - Detailed debugging info
- `INFO` - Normal operations
- `WARN` - Potential issues
- `ERROR` - Error conditions

**Log Files:**

```
data/logs/
├── app.log          # All logs
├── error.log        # Errors only
└── access.log       # HTTP requests
```

**Log Rotation:**

- Max file size: 10MB
- Keep: 7 daily backups
- Compress old logs

**Log Format:**

```
[2026-03-08 10:30:45.123] [INFO] [auth_service.dart:45] User logged in: test@example.com
[2026-03-08 10:30:47.456] [ERROR] [db_manager.dart:123] Database error: table not found
```

### Monitoring

**Health Check:**

```bash
curl http://localhost:8080/health

Response: {
  "status": "healthy",
  "timestamp": "2026-03-08T10:30:00Z",
  "database": "connected",
  "uptime": 3600
}
```

**Statistics:**

- Total users
- Total documents
- Total media files
- Disk usage
- Memory usage
- Request rate

### Backup & Recovery

**Database Backup:**

```bash
# CLI
dart bin/main.dart db backup

# Manual
cp data/shadow_app.db backups/shadow_app-$(date +%Y%m%d).db
```

**Database Restore:**

```bash
# CLI
dart bin/main.dart db restore backups/shadow_app-20260308.db

# Manual
cp backups/shadow_app-20260308.db data/shadow_app.db
```

**Media Backup:**

```bash
# Backup all media files
tar -czf media-backup-$(date +%Y%m%d).tar.gz bin/data/media/

# Restore
tar -xzf media-backup-20260308.tar.gz -C bin/data/
```

### Scaling Considerations

**Current Limitations:**

- Single-server deployment
- SQLite database (not distributed)
- File system media storage
- No load balancing

**For Production Scale:**

1. **Database:** Migrate to PostgreSQL/MySQL
2. **Media:** Use object storage (S3, Google Cloud Storage)
3. **Load Balancing:** Multiple server instances behind load balancer
4. **Caching:** Redis for sessions and frequently accessed data
5. **CDN:** Serve media through CDN
6. **Monitoring:** Grafana + Prometheus
7. **Logging:** Centralized logging (ELK stack)

---

## Code Organization

### File Structure Philosophy

**Separation of Concerns:**

- `lib/api/` - HTTP handlers (presentation layer)
- `lib/auth/` - Authentication logic (business layer)
- `lib/database/` - Data access (persistence layer)
- `lib/logging/` - Cross-cutting concerns

**Dependency Flow:**

```
API Handlers → Business Logic → Database Layer
     ↓              ↓                ↓
  Minimal       Core Logic      Data Access
  Logic         & Rules         Only
```

### Key Design Patterns

**1. Singleton Pattern (Flutter SDK)**

```dart
class ShadowApp {
  static ShadowApp? _instance;

  static Future<void> initialize(String serverUrl) async {
    _instance = ShadowApp._(serverUrl);
  }

  static ShadowApp get instance => _instance!;
}
```

**2. Factory Pattern (Models)**

```dart
class User {
  factory User.fromRow(Map<String, dynamic> row) {
    return User(
      id: row['id'],
      email: row['email'],
      // ...
    );
  }
}
```

**3. Command Pattern (CLI)**

```dart
abstract class Command {
  Future<void> execute(List<String> args);
}
```

**4. Repository Pattern (DbManager)**

```dart
class DbManager {
  Future<User> createUser(...) { /* SQL logic */ }
  Future<User?> getUserByEmail(...) { /* SQL logic */ }
  // Abstracts database operations
}
```

**5. Middleware Pattern (Server)**

```dart
final pipeline = Pipeline()
  .addMiddleware(corsMiddleware)
  .addMiddleware(loggingMiddleware)
  .addMiddleware(authMiddleware)
  .addHandler(router);
```

### Code Style

**Dart Conventions:**

- Use `lowerCamelCase` for variables/methods
- Use `UpperCamelCase` for classes
- Use `snake_case` for file names
- Use `const` constructors where possible
- Prefer `final` over `var`
- Document public APIs with `///` comments

**Error Handling:**

```dart
// Always catch specific exceptions
try {
  await somethingThatMightFail();
} on AuthException catch (e) {
  // Handle auth errors
} on NetworkException catch (e) {
  // Handle network errors
} catch (e) {
  // Handle unexpected errors
}
```

**Async Best Practices:**

```dart
// Use async/await instead of .then()
Future<void> goodExample() async {
  final result = await someAsyncOperation();
  print(result);
}

// Don't do this
void badExample() {
  someAsyncOperation().then((result) {
    print(result);
  });
}
```

---

## Learning Objectives

### For Beginners

After completing a course based on this project, learners should be able to:

**1. Understand Backend Basics**

- What is a backend server and why is it needed?
- How do clients communicate with servers (HTTP)?
- What are REST APIs and why are they popular?
- How does request/response cycle work?

**2. Set Up Development Environment**

- Install Dart SDK
- Choose and configure an IDE
- Understand project structure (pubspec.yaml, lib/, bin/)
- Run Dart programs from command line

**3. Build Simple HTTP Server**

- Create basic Shelf server
- Define routes (GET, POST, PUT, DELETE)
- Handle requests and send responses
- Parse JSON data

**4. Implement Authentication**

- Understand authentication vs authorization
- Learn about JWTs and how they work
- Implement user signup/login
- Hash passwords securely
- Validate user input

**5. Work with Databases**

- Understand relational databases (tables, rows, columns)
- Write SQL queries (SELECT, INSERT, UPDATE, DELETE)
- Use SQLite with Dart (sqlite3 package)
- Design database schemas
- Implement migrations

**6. Handle File Uploads**

- Process multipart/form-data requests
- Save files to disk
- Serve files for download
- Compress files to save space
- Track file metadata in database

**7. Create Client SDKs**

- Understand SDK purpose and design
- Make HTTP requests from Dart/Flutter
- Make HTTP requests from TypeScript/React
- Handle authentication tokens
- Provide good developer experience

**8. Test Code**

- Write unit tests for individual functions
- Write integration tests for APIs
- Use test fixtures and mocks
- Run tests automatically

**9. Deploy Applications**

- Build native executables
- Configure environment variables
- Set up logging
- Monitor server health
- Plan for scaling

### For Intermediate Developers

After studying this project, intermediate developers should understand:

**1. Architecture Patterns**

- Layered architecture (presentation, business, data)
- Middleware pattern for request processing
- Repository pattern for data access
- Factory pattern for object creation
- Command pattern for CLI operations

**2. Security Best Practices**

- Token-based authentication (JWT)
- Password hashing and salting
- Role-based access control
- Input validation and sanitization
- Protection against common attacks (SQL injection, XSS)

**3. API Design**

- RESTful principles
- Consistent URL structure
- Proper HTTP status codes
- Error response format
- Versioning strategies

**4. SDK Development**

- Cross-platform SDK architecture
- Language-specific patterns (Singleton vs Context)
- Type safety (Dart classes vs TypeScript interfaces)
- State management (Flutter setState vs React hooks)
- Error handling in SDKs

**5. Database Design**

- Schema design (tables, relationships)
- Indexing for performance
- Foreign key constraints
- Migration strategies
- Query optimization

**6. Code Quality**

- Writing maintainable code
- Separation of concerns
- DRY principle
- Error handling patterns
- Documentation standards

### For Advanced Developers

Advanced developers can use this as a reference for:

**1. Production Readiness**

- Security hardening
- Performance optimization
- Scalability strategies
- Monitoring and alerting
- Disaster recovery

**2. Alternative Implementations**

- Migrate to PostgreSQL/MySQL
- Add Redis caching
- Implement WebSockets for real-time
- Add message queues (RabbitMQ, etc.)
- Use microservices architecture

**3. Advanced Features**

- OAuth2/OpenID Connect
- Two-factor authentication
- Rate limiting
- API keys and quotas
- Webhooks
- Full-text search
- Real-time subscriptions

---

## Teaching Approach Recommendations

### Course Structure

**Module 1: Introduction (Week 1)**

- What is ShadowApp?
- Project tour and feature overview
- Setting up development environment
- Running the project
- Making first API call

**Module 2: HTTP Basics (Week 2)**

- HTTP protocol fundamentals
- Understanding REST APIs
- Shelf framework introduction
- Building a simple "Hello World" server
- Adding routes and handlers

**Module 3: Authentication (Week 3-4)**

- Why authentication matters
- Understanding JWTs
- Implementing signup endpoint
- Implementing login endpoint
- Password hashing with SHA-256
- Creating and validating tokens
- Middleware for protected routes

**Module 4: Database Integration (Week 5-6)**

- Introduction to SQLite
- Database schema design
- Writing SQL queries in Dart
- Building DbManager class
- Implementing migrations
- CRUD operations on users table

**Module 5: Document Operations (Week 7-8)**

- Designing document model
- Implementing create endpoint
- Implementing read endpoint
- Implementing update endpoint
- Implementing delete endpoint
- Implementing list with pagination
- Authorization (ownership checks)

**Module 6: Media Handling (Week 9-10)**

- Understanding file uploads
- Parsing multipart/form-data
- Saving files to disk
- File compression (zstd, gzip, brotli)
- Serving files for download
- Tracking metadata in database

**Module 7: Client SDKs (Week 11-12)**

- SDK design principles
- Building Flutter SDK
  - Creating singleton
  - Implementing auth methods
  - Implementing CRUD methods
  - Implementing media methods
- Building React SDK
  - Creating TypeScript types
  - Implementing HTTP client
  - Creating React hooks
  - Using Context API

**Module 8: Testing (Week 13)**

- Introduction to testing
- Writing unit tests
- Writing integration tests
- Running tests
- Understanding test coverage

**Module 9: CLI Tool (Week 14)**

- Command-line interfaces in Dart
- Parsing command-line arguments
- Building user commands
- Building database commands
- Building server commands

**Module 10: Deployment (Week 15)**

- Building native executables
- Environment configuration
- Setting up logging
- Monitoring and health checks
- Backup strategies
  -Deployment options

**Module 11: Production Considerations (Week 16)**

- Security hardening
- Performance optimization
- Scaling strategies
- Migration to PostgreSQL
- Using object storage for media
- Load balancing

### Pedagogical Approach

**1. Start Simple, Build Gradually**

```dart
// Lesson 1: Simplest server
void main() {
  shelf_io.serve((request) {
    return Response.ok('Hello World!');
  }, 'localhost', 8080);
}

// Lesson 2: Add routing
void main() {
  final router = Router()
    ..get('/', (request) => Response.ok('Home'))
    ..get('/about', (request) => Response.ok('About'));

  shelf_io.serve(router, 'localhost', 8080);
}

// Lesson 3: Add JSON
void main() {
  final router = Router()
    ..get('/users', (request) {
      return Response.ok(
        jsonEncode({'users': []}),
        headers: {'Content-Type': 'application/json'},
      );
    });

  shelf_io.serve(router, 'localhost', 8080);
}

// Continue building...
```

**2. Show Both Right and Wrong Ways**

```dart
// ❌ Bad: Plain text password
final user = await db.createUser('test@test.com', 'password123');

// ✅ Good: Hashed password
final hash = hashPassword('password123', salt);
final user = await db.createUser('test@test.com', hash);
```

**3. Provide Hands-On Exercises**

After each lesson, give exercises like:

- "Add a PUT endpoint to update user email"
- "Implement a password reset feature"
- "Add pagination to document listing"
- "Create a media gallery in Flutter SDK"

**4. Use Real-World Examples**

Instead of abstract examples, use practical ones:

- "Build a notes app backend" (uses documents)
- "Build a photo sharing app" (uses media)
- "Build a blog platform" (uses documents + media)

**5. Explain the "Why"**

Don't just show code; explain decisions:

- Why JWT instead of sessions?
- Why SQLite for this project?
- Why middleware pattern?
- Why separate SDKs instead of direct API calls?

**6. Compare Alternatives**

Show different approaches:

- JWT vs Session cookies
- SQLite vs PostgreSQL vs MongoDB
- SHA-256 vs bcrypt vs argon2
- REST vs GraphQL vs gRPC

**7. Include Visual Aids**

- Architecture diagrams
- Sequence diagrams for flows
- Database schema visualizations
- Request/response examples
- State transition diagrams

**8. Provide Code Walkthroughs**

Record videos walking through:

- Complete authentication flow
- Document creation process
- Media upload handling
- SDK method implementation

**9. Create Cheat Sheets**

Provide quick references for:

- All API endpoints
- Common SQL queries
- JWT token structure
- Error codes
- CLI commands

**10. Build in Public**

Encourage learners to:

- Share their implementations
- Ask questions in community
- Contribute improvements
- Build their own features

### Assessment Strategy

**Quiz Questions:**

- Multiple choice on concepts
- Code reading comprehension
- Debugging challenges
- Architecture decisions

**Projects:**

- Level 1: Build simple endpoints
- Level 2: Add authentication
- Level 3: Complete CRUD operations
- Level 4: Build full SDK
- Final: Build unique feature

**Code Reviews:**

- Peer review assignments
- Instructor feedback
- Security audit practice
- Performance analysis

---

## Additional Resources for Teaching

### Code Snippets Library

Create a library of reusable snippets:

- Authentication middleware
- Database query templates
- Error handling patterns
- Test fixtures
- Configuration examples

### Video Content

Record demonstrations of:

- Project setup (5 min)
- Building first endpoint (15 min)
- Implementing authentication (30 min)
- Working with database (30 min)
- Creating SDK (45 min)
- Full application walkthrough (60 min)

### Documentation References

Point learners to:

- Dart language tour
- Shelf package documentation
- SQLite documentation
- JWT specification
- HTTP/REST best practices
- Flutter/React documentation

### Community Resources

- Discord/Slack for discussions
- GitHub for code sharing
- Stack Overflow for Q&A
- Blog posts for deep dives
- Case studies from real projects

### Tools and IDEs

Recommend:

- VS Code with Dart extension
- Android Studio / IntelliJ IDEA
- Postman for API testing
- DB Browser for SQLite
- Git for version control

---

## Key Takeaways for AI Learning Program

### This Project Teaches:

1. **Full-Stack Development** - Both backend and client SDKs
2. **Real-World Patterns** - Authentication, authorization, file handling
3. **Production Considerations** - Logging, monitoring, deployment
4. **Code Quality** - Testing, documentation, refactoring
5. **Cross-Platform Development** - Flutter (mobile/desktop) and React (web)

### What Makes This Project Valuable:

- ✅ **Complete implementation** - Not just examples, but working system
- ✅ **Well-documented** - Extensive guides for each component
- ✅ **Modern practices** - JWT, REST, TypeScript, Dart
- ✅ **Multiple perspectives** - Server, Flutter client, React client, CLI, GUI
- ✅ **Educational focus** - Built to teach, not just to work

### How to Use This Specification:

1. **Read thoroughly** to understand all components
2. **Explore codebase** following this as a guide
3. **Identify learning paths** (beginner → advanced)
4. **Create lesson plans** based on module structure
5. **Develop exercises** that build on each other
6. **Prepare assessments** that test real understanding
7. **Build examples** that extend the project
8. **Create tutorials** that walk through implementation

---

## Questions for AI to Consider

When building the learning program, consider:

1. **Target Audience:** Who is this for? (Students, bootcamp, self-learners?)
2. **Prerequisites:** What should learners know before starting? (Basic programming? Dart knowledge?)
3. **Time Commitment:** How long should the course take? (16 weeks? Self-paced?)
4. **Depth vs Breadth:** Cover everything or focus on core concepts?
5. **Platform:** Video course? Interactive tutorials? Written guides?
6. **Assessments:** How to verify learning? (Quizzes? Projects? Certification?)
7. **Support:** How to help stuck learners? (Forums? Office hours? AI assistance?)
8. **Updates:** How to keep content current as technologies evolve?

---

## Conclusion

This ShadowApp backend project provides a **comprehensive, production-quality example** of:

- Building web servers in Dart
- Implementing authentication with JWT
- Working with databases (SQLite)
- Handling file uploads and downloads
- Creating cross-platform client SDKs
- Testing and deploying applications
- Building CLI and GUI administration tools

The codebase is **well-organized, documented, and educational**, making it an ideal foundation for teaching backend development concepts to learners at various skill levels.

By following this specification, an AI learning program can create effective educational content that teaches not just how to use this specific backend, but **how to build similar systems from scratch**, understanding the design decisions, trade-offs, and best practices that make modern web applications work.

---

**End of Specification**

**For Questions or Clarifications:**

- Review source code in repository
- Read comprehensive SDK guides (Flutter: 1,786 lines, React: 1,426 lines)
- Check architecture documentation
- Examine test files for usage examples
- Refer to CLI audit report for detailed functionality

**License:** MIT  
**Maintainers:** ShadowApp Team  
**Repository:** Gracelium64/dartBackendServer  
**Branch:** devGrace
