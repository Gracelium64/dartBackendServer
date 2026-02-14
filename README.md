# Shadow App Backend

A **Dart-only learning backend server** for Flutter developers. Write your own backend, understand how it works, and deploy with confidence.

```
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🚀 Shadow App Backend Server v0.1.0 🚀                     ║
║                                                                                ║
║            A Transparent Learning Backend for Flutter Developers               ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
```

## 🎯 Mission

Build a backend server written **entirely in Dart** that teaches you backend development while serving as a learning tool for your Flutter apps. Unlike Firebase, you have complete transparency and learning value.

## ✨ Features

- **Authentication**: Signup, login, JWT tokens, token refresh with password hashing
- **Database**: SQLite with CRUD operations on documents in collections
- **Media Storage**: Upload, compress, and store images/videos directly in database
- **Access Control**: Per-collection permission rules (read/write/public)
- **Live Logging**: Real-time audit trail of all database actions
- **Admin Console**: Full database management terminal UI
- **Flutter SDK**: Simple, intuitive package for your Flutter apps
- **Gmail Integration**: Monthly log reports sent automatically to admin email
- **Production Ready**: Designed to scale from local dev to cloud deployment

## 📚 Quick Start

### For Backend Operators

```bash
# 1. Install dependencies
dart pub get

# 2. Start the server
dart bin/main.dart server --port 8080

# 3. Monitor logs (second terminal)
dart bin/main.dart log-tail --follow

# 4. Admin console (third terminal)
dart bin/main.dart admin --admin-key <key-from-startup>
```

**See**: [Operator Manual](docs/OPERATOR_MANUAL.md)

### For Flutter Developers

```dart
import 'package:shadow_app_backend/shadow_app.dart';

void main() async {
  // Initialize SDK
  await ShadowApp.initialize(serverUrl: 'http://localhost:8080');
  runApp(const MyApp());
}

// Use in your widgets
final doc = await ShadowApp.collection('notes').create({
  'title': 'My Note',
  'text': 'Hello world'
});

final updated = await ShadowApp.collection('notes').update(doc.id, {
  'text': 'Updated!'
});

await ShadowApp.collection('notes').delete(doc.id);
```

**See**: [Flutter SDK Guide](docs/FLUTTER_SDK_GUIDE.md)

## 📖 Complete Documentation

| File | For | Contains |
|------|-----|----------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Developers | System design, data models, database schema, API contract |
| [OPERATOR_MANUAL.md](docs/OPERATOR_MANUAL.md) | Operators | Setup, running, monitoring, troubleshooting |
| [FLUTTER_SDK_GUIDE.md](docs/FLUTTER_SDK_GUIDE.md) | Flutter Devs | SDK usage, examples, learning notes |
| [MAINTENANCE_SCALING_GUIDE.md](docs/MAINTENANCE_SCALING_GUIDE.md) | DevOps | Backup, scaling, deployment strategies |

## 🏗️ Project Structure

```
dartBackendServer/
├── bin/main.dart              # Server + log-tail + admin CLI
├── lib/
│   ├── server.dart            # HTTP server & routes
│   ├── config.dart            # Configuration loading
│   ├── database/              # SQLite database layer
│   ├── auth/                  # JWT & password hashing
│   ├── api/                   # CRUD endpoint handlers
│   └── logging/               # Audit logs & Gmail integration
├── flutter_sdk/lib/           # Flutter package source
│   ├── shadow_app.dart
│   ├── auth_service.dart
│   ├── crud_service.dart
│   └── media_service.dart
├── docs/                      # User manuals & guides
└── data/                      # SQLite DB + logs (created at runtime)
```

## 🔐 Security

- **Passwords**: PBKDF2 hashing with 100k iterations
- **Tokens**: JWT (HS256) with 24-hour expiry
- **Authorization**: Per-collection access rules
- **Audit**: Every action logged with user & timestamp
- **Email**: Gmail for monthly log delivery

## 🚀 Getting Started

### Install

```bash
git clone <repo> dartBackendServer
cd dartBackendServer
dart pub get
```

### Run

```bash
# Server starts on http://localhost:8080
dart bin/main.dart server --port 8080
```

### Test

```bash
# Health check
curl http://localhost:8080/health

# Signup
curl -X POST http://localhost:8080/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"pass123456"}'

# Login
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@test.com","password":"pass123456"}'
```

## 💡 What You'll Learn

- ✅ Backend HTTP server architecture
- ✅ JWT authentication & tokens
- ✅ Database design & SQL
- ✅ RESTful API design
- ✅ Password security & hashing
- ✅ Logging & monitoring
- ✅ Scaling strategies
- ✅ Deployment & DevOps

## 📊 API Endpoints

```
POST   /auth/signup                              # Create user
POST   /auth/login                               # Get JWT token
POST   /auth/refresh                             # Refresh token

POST   /api/collections/{id}/documents          # Create document
GET    /api/collections/{id}/documents/{docId}  # Read document
PUT    /api/collections/{id}/documents/{docId}  # Update document
DELETE /api/collections/{id}/documents/{docId}  # Delete document
GET    /api/collections/{id}/documents          # List documents

POST   /api/media/upload                         # Upload media
GET    /api/media/download/{mediaId}            # Download media

GET    /health                                   # Health check
```

## 🧪 Testing

```bash
dart test              # Unit tests
dart bin/main.dart server --log-level DEBUG     # Verbose logging
dart bin/main.dart test-email --to admin@example.com  # Test Gmail
```

## 📚 Code Comments

Every file contains extensive **inline code comments** explaining how things work, written specifically for Flutter developers new to backend development. Start with:

- `lib/auth/auth_service.dart` → JWT & tokens explained
- `lib/database/db_manager.dart` → Database queries
- `lib/auth/password_utils.dart` → Security & hashing
- `flutter_sdk/lib/shadow_app.dart` → SDK usage

## 🌐 Deployment

### Local Dev
- SQLite (file-based)
- Run on localhost:8080
- Everything self-contained

### Production (Small)
- Single Ubuntu server
- SQLite + WAL mode
- Gmail for log reports
- Monitor with log-tail

### Production (Large)
- PostgreSQL cluster
- Multiple server instances
- Redis caching
- S3 for media
- Load balancer (Nginx)
- See: [Maintenance & Scaling Guide](docs/MAINTENANCE_SCALING_GUIDE.md)

## ✅ Implemented

- [x] Dart-only server with Shelf framework
- [x] SQLite database with schema
- [x] Authentication (signup, login, JWT, password hashing)
- [x] CRUD operations with access control
- [x] Media upload/download with compression
- [x] Audit logging with 7-day retention
- [x] Live log tail with ASCII UI
- [x] Admin console with terminal UI
- [x] Flutter SDK package with CRUD/auth/media
- [x] Comprehensive documentation (4 user manuals)
- [x] Gmail integration for monthly logs

## 📋 Next Steps

1. **Deploy locally**: `dart bin/main.dart server`
2. **Read architecture**: [ARCHITECTURE.md](docs/ARCHITECTURE.md)
3. **Operate the server**: [OPERATOR_MANUAL.md](docs/OPERATOR_MANUAL.md)
4. **Build Flutter apps**: [Flutter SDK Guide](docs/FLUTTER_SDK_GUIDE.md)
5. **Scale up**: [Maintenance & Scaling](docs/MAINTENANCE_SCALING_GUIDE.md)

---

**Built for Flutter Developers Learning Backend Development** 🚀
