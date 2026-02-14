# Shadow App Backend - Architecture Overview

## Project Structure

```
dartBackendServer/
├── bin/
│   └── main.dart                 # CLI entrypoint with server/log/admin modes
├── lib/
│   ├── server.dart               # Main server scaffolding
│   ├── config.dart               # Configuration and environment loading
│   ├── database/
│   │   ├── db_manager.dart       # SQLite connection and management
│   │   ├── models.dart           # Database models (User, Collection, Document, etc.)
│   │   └── migrations.dart       # Schema initialization and migrations
│   ├── auth/
│   │   ├── auth_service.dart     # JWT token generation, validation
│   │   ├── password_utils.dart   # Password hashing with bcrypt
│   │   └── rule_engine.dart      # Per-collection access control rules
│   ├── api/
│   │   ├── routes.dart           # HTTP route definitions
│   │   ├── handlers/
│   │   │   ├── auth_handler.dart # Signup, login, token refresh
│   │   │   ├── crud_handler.dart # Create, Read, Update, Delete endpoints
│   │   │   └── media_handler.dart# Media upload, download, compression
│   │   └── middleware.dart       # Request logging, auth validation
│   ├── logging/
│   │   ├── logger.dart           # Central logging system
│   │   ├── log_manager.dart      # File rotation (7-day), archiving
│   │   └── email_service.dart    # Gmail integration for monthly reports
│   ├── compression/
│   │   └── media_utils.dart      # Media compression/decompression
│   └── utils/
│       ├── json_utils.dart       # JSON serialization helpers
│       └── validators.dart       # Input validation
├── flutter_sdk/
│   ├── pubspec.yaml              # Flutter package manifest
│   ├── lib/
│   │   ├── shadow_app.dart       # Main SDK entry point
│   │   ├── models.dart           # Data models for Flutter
│   │   ├── crud_service.dart     # CRUD method wrappers
│   │   ├── auth_service.dart     # Auth helpers for Flutter apps
│   │   └── media_service.dart    # Media upload/download helpers
│   └── example/
│       └── main.dart             # Example Flutter app using SDK
├── test/
│   ├── auth_test.dart
│   ├── crud_test.dart
│   └── compression_test.dart
├── docs/
│   ├── ARCHITECTURE.md
│   ├── OPERATOR_MANUAL.md
│   ├── FLUTTER_SDK_GUIDE.md
│   └── MAINTENANCE_SCALING_GUIDE.md
└── data/
    ├── shadow_app.db            # SQLite database (created at runtime)
    └── logs/                    # Log files (created at runtime)
```

## High-Level Flow

### Server Mode
1. **CLI Entry**: `dart bin/main.dart server --port 8080 --db-path data/shadow_app.db`
2. **Initialization**: Load config, initialize SQLite, create tables if needed
3. **HTTP Server Startup**: Listen on port 8080 using Shelf framework
4. **Request Processing**:
   - Middleware validates JWT tokens
   - Routes dispatch to handlers (auth, CRUD, media)
   - Handlers query database, apply rules, return JSON responses
   - All actions logged to file and memory stream (for live log tail)

### Log Tail Mode
1. **CLI Entry**: `dart bin/main.dart log-tail`
2. **Stream Subscription**: Subscribe to live action log stream from server process (via IPC or file tail)
3. **ASCII Display**: Show formatted table of recent actions (user, action, timestamp, collection, status)
4. **Auto-rotation**: Detect when log files rollover (daily)

### Admin Console Mode
1. **CLI Entry**: `dart bin/main.dart admin --admin-key <secret>`
2. **Interactive Prompt**: Admin can issue CRUD commands, review logs, manage users/rules
3. **Full Database Access**: Bypass normal rules for admin queries
4. **ASCII Menu UI**: Display options and formatted results

## API Contract (JSON)

All endpoints use JSON request/response bodies. Common structure:

```json
{
  "success": true,
  "data": { /* response data */ },
  "error": null,
  "timestamp": "2026-02-14T10:30:00Z"
}
```

### Auth Endpoints
- `POST /auth/signup` → Register user
- `POST /auth/login` → Login with email/password, get JWT
- `POST /auth/refresh` → Refresh expired JWT token

### CRUD Endpoints
- `POST /api/collections/{id}/documents` → Create document
- `GET /api/collections/{id}/documents/{docId}` → Read document
- `PUT /api/collections/{id}/documents/{docId}` → Update document
- `DELETE /api/collections/{id}/documents/{docId}` → Delete document
- `GET /api/collections/{id}/documents` → List documents (with pagination)

### Media Endpoints
- `POST /api/media/upload` → Upload and compress media, store in document
- `GET /api/media/download/{mediaId}` → Download and decompress media

## Database Schema (SQLite)

### Users
- id (TEXT, primary key, UUID)
- email (TEXT, unique)
- password_hash (TEXT)
- role (TEXT: admin, user)
- created_at (INTEGER, Unix timestamp)
- updated_at (INTEGER, Unix timestamp)

### Collections
- id (TEXT, primary key, UUID)
- owner_id (TEXT, FK to Users)
- name (TEXT)
- rules (BLOB, JSON: read/write roles, public flag)
- created_at (INTEGER)
- updated_at (INTEGER)

### Documents
- id (TEXT, primary key, UUID)
- collection_id (TEXT, FK to Collections)
- owner_id (TEXT, FK to Users)
- data (TEXT, JSON blob)
- created_at (INTEGER)
- updated_at (INTEGER)

### MediaBlobs
- id (TEXT, primary key, UUID)
- document_id (TEXT, FK to Documents)
- file_name (TEXT)
- mime_type (TEXT)
- original_size (INTEGER)
- compressed_size (INTEGER)
- compression_algo (TEXT: gzip, etc.)
- blob_data (BLOB, binary compressed data)
- created_at (INTEGER)

### AuditLog
- id (TEXT, primary key, UUID)
- user_id (TEXT, FK to Users)
- action (TEXT: CREATE, READ, UPDATE, DELETE, LOGIN)
- resource_type (TEXT: document, user, collection)
- resource_id (TEXT)
- status (TEXT: success, failed)
- error_message (TEXT, nullable)
- timestamp (INTEGER)

## Logging Strategy

1. **Live Action Stream**: In-memory circular buffer of recent actions, subscribed by log-tail CLI.
2. **File Logs**: Daily rotation → `data/logs/shadow_app_2026-02-14.log`
3. **Retention**: Keep 7 days of logs; older files auto-deleted.
4. **Monthly Export**: First day of month, email all previous month's logs to admin with Gmail.
5. **Format**: Tab-separated TSV for easy parsing and grepping.

```
[2026-02-14T10:30:05Z] [user@example.com] [CREATE] [document] [doc-123] [success] [collection-456]
[2026-02-14T10:31:10Z] [admin@example.com] [LOGIN] [user] [user@example.com] [success] [-]
```

## Authentication & Authorization

1. **Signup**: Email + password → hash with bcrypt, store in Users table.
2. **Login**: Email + password → verify hash, return JWT (RS256, 24h expiry).
3. **Token Refresh**: POST /auth/refresh with old JWT → new JWT.
4. **Per-Collection Rules**: Each collection has rules JSON:
   ```json
   {
     "read": ["admin", "owner"],
     "write": ["admin", "owner"],
     "public_read": false
   }
   ```
5. **Rule Engine**: Before CRUD operation, check user role against rules; deny if not permitted.

## Flutter SDK Design

The Flutter SDK is a simple wrapper that:
1. Manages server connection URL and stored JWT token.
2. Provides CRUD methods: `create()`, `read()`, `update()`, `delete()`, `list()`.
3. Handles media upload/download with transparent compression.
4. Targets beginner Flutter developers with extensive inline comments and examples.

```dart
// Example usage in Flutter app
final db = ShadowApp(serverUrl: 'http://localhost:8080');

// Authenticate
await db.auth.login('user@example.com', 'password');

// Create a document
final doc = await db.collection('notes').create({
  'title': 'My first note',
  'text': 'Hello world'
});

// Read a document
final note = await db.collection('notes').read(doc.id);

// Update
await db.collection('notes').update(doc.id, {
  'text': 'Updated text'
});

// Delete
await db.collection('notes').delete(doc.id);
```

## Deployment & Scaling Notes

- **Local Dev**: Run on localhost:8080; SQLite file-based DB works fine.
- **Production Scale**: Migrate to PostgreSQL for concurrent users; add read replicas, reverse proxy (Nginx).
- **Admin Console**: Can run as separate process on same machine; connects to same DB.
- **Log Tail**: Lightweight CLI that tails live log stream; can run on admin's machine.

---

This architecture emphasizes learning, simplicity, and extensibility for a Flutter developer new to backend systems.
