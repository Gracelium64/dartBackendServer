# Shadow App Flutter SDK

Flutter SDK for integrating with the Shadow App Dart Backend Server. It provides Dart-native authentication, document CRUD, and media handling for Flutter applications.

## Current Access Points

- Production: `https://shadow-app-server.onrender.com`
- Local/dev: `http://localhost:8080` (or your LAN/server URL)

## Features

- Authentication with signup, login, logout, and token persistence
- Document CRUD operations against backend collections
- Media upload and download support
- Offline-friendly local caching options
- Dart-native API for Flutter apps with no JavaScript bridge

## Installation

Add the package to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  shadow_app_backend:
    path: ../dartBackendServer/flutter_sdk
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:shadow_app_backend/shadow_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ShadowApp.initialize(
    serverUrl: 'https://shadow-app-server.onrender.com',
    enableOfflineMode: true,
  );

  runApp(const MyApp());
}
```

## Backend Operator Notes

The backend now includes additional operator-only account maintenance and reporting features that affect Flutter clients indirectly:

- Operators can change a user's login email from the admin console.
- Operators can reset a user's password with hashing, using either manual entry or a generated random password.
- Operators can configure a Gmail sender account and email full admin report bundles, or export the same bundle locally.

What this means for Flutter apps:

- Users may need to log in with a different email after an operator account update.
- Password resets happen on the backend; the Flutter SDK does not expose a client-side admin reset API.
- Existing tokens continue to work until expiry, after which re-authentication uses the new credentials.

## Documentation

- Full guide: ../docs/FLUTTER_SDK_GUIDE.md
- Shared SDK guide: ../docs/SDK_GUIDE.md
- Backend operator manual: ../docs/OPERATOR_MANUAL.md
