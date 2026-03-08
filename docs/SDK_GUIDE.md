# Shadow App Backend - SDK Guide

Complete guide for integrating with the Shadow App Backend Server using multiple SDKs and tools.

## Table of Contents

1. [Dart/Flutter SDK](#dartflutter-sdk)
2. [CLI Client (Dart)](#cli-client-dart)
3. [REST API](#rest-api)
4. [cURL Examples](#curl-examples)
5. [JavaScript/Node.js](#javascriptnode.js)
6. [Python](#python)
7. [Authentication](#authentication)
8. [Error Handling](#error-handling)
9. [Rate Limiting & Best Practices](#rate-limiting--best-practices)

---

## Dart/Flutter SDK

The native Dart/Flutter SDK provides the most seamless integration.

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  shadow_app:
    path: ../flutter_sdk/
```

Then run:

```bash
dart pub get
# or
flutter pub get
```

### Basic Usage

```dart
import 'package:shadow_app/shadow_app.dart';

void main() async {
  // Initialize
  final app = ShadowApp(
    serverUrl: 'http://192.168.1.100:8080',
    projectId: 'my-project',
  );

  // Authenticate
  await app.auth.login('user@example.com', 'password');

  // Create a document
  await app.firestore.collection('users').add({
    'name': 'John Doe',
    'email': 'john@example.com',
  });

  // Read documents
  final docs = await app.firestore.collection('users').list();
  for (final doc in docs) {
    print('${doc.id}: ${doc.data}');
  }
}
```

### API Reference

See [FLUTTER_SDK_GUIDE.md](FLUTTER_SDK_GUIDE.md) for detailed API documentation.

---

## CLI Client (Dart)

Command-line tool for terminal access from any machine.

### Installation

```bash
cd cli_client
pub get
chmod +x bin/client.dart
```

### Quick Start

```bash
# Check server health
dart bin/client.dart --server http://192.168.1.100:8080 --health

# Login
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password mypass \
  --login \
  --list-users

# Perform CRUD operations
dart bin/client.dart \
  --server http://192.168.1.100:8080 \
  --email user@example.com \
  --password mypass \
  --login \
  --create-collection "posts"
```

See [cli_client/README.md](../cli_client/README.md) for comprehensive documentation.

---

## REST API

Direct HTTP API endpoints for integration with any language or tool.

### Base URL

```
http://SERVER_IP:PORT
```

Example: `http://192.168.1.100:8080`

### Authentication

#### User Login

**Endpoint:** `POST /auth/login`

**Request:**

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "user_123",
    "email": "user@example.com",
    "role": "user"
  }
}
```

**Usage:** Include token in `Authorization` header:

```
Authorization: Bearer <token>
```

#### User Registration

**Endpoint:** `POST /auth/signup`

**Request:**

```json
{
  "email": "newuser@example.com",
  "password": "password123"
}
```

---

### Users API

#### List All Users (Admin Only)

**Endpoint:** `GET /api/users`

**Headers:**

```
Authorization: Bearer <admin_token>
```

**Response:**

```json
[
  {
    "id": "user_123",
    "email": "user@example.com",
    "role": "user",
    "created_at": 1672531200000,
    "updated_at": 1672531200000
  }
]
```

---

### Collections API

#### List Collections

**Endpoint:** `GET /api/collections`

**Headers:**

```
Authorization: Bearer <token>
```

**Response:**

```json
[
  {
    "id": "col_abc123",
    "name": "posts",
    "owner_id": "user_123",
    "rules": {
      "read": ["owner"],
      "write": ["owner"],
      "public_read": false
    },
    "created_at": 1672531200000
  }
]
```

#### Create Collection

**Endpoint:** `POST /api/collections`

**Headers:**

```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request:**

```json
{
  "name": "posts"
}
```

**Response:** (201 Created)

```json
{
  "id": "col_abc123",
  "name": "posts",
  "owner_id": "user_123",
  "rules": {
    "read": ["owner"],
    "write": ["owner"],
    "public_read": false
  },
  "created_at": 1672531200000
}
```

---

### Documents API

#### List Documents

**Endpoint:** `GET /api/collections/{collectionId}/documents`

**Query Parameters:**

- `limit`: Number of documents (default: 10)
- `offset`: Skip N documents (default: 0)

**Response:**

```json
[
  {
    "id": "doc_xyz789",
    "collection_id": "col_abc123",
    "owner_id": "user_123",
    "data": {
      "title": "My Post",
      "content": "Hello world"
    },
    "created_at": 1672531200000,
    "updated_at": 1672531200000
  }
]
```

#### Create Document

**Endpoint:** `POST /api/collections/{collectionId}/documents`

**Request:**

```json
{
  "data": {
    "title": "My Post",
    "content": "Hello world"
  }
}
```

**Response:** (201 Created)

```json
{
  "id": "doc_xyz789",
  "collection_id": "col_abc123",
  "owner_id": "user_123",
  "data": {
    "title": "My Post",
    "content": "Hello world"
  },
  "created_at": 1672531200000,
  "updated_at": 1672531200000
}
```

#### Read Document

**Endpoint:** `GET /api/collections/{collectionId}/documents/{documentId}`

**Response:**

```json
{
  "id": "doc_xyz789",
  "collection_id": "col_abc123",
  "owner_id": "user_123",
  "data": {
    "title": "My Post",
    "content": "Hello world"
  },
  "created_at": 1672531200000,
  "updated_at": 1672531200000
}
```

#### Update Document

**Endpoint:** `PUT /api/collections/{collectionId}/documents/{documentId}`

**Request:**

```json
{
  "data": {
    "title": "Updated Post",
    "content": "Updated content"
  }
}
```

**Response:** (200 OK)

```json
{
  "id": "doc_xyz789",
  "collection_id": "col_abc123",
  "owner_id": "user_123",
  "data": {
    "title": "Updated Post",
    "content": "Updated content"
  },
  "created_at": 1672531200000,
  "updated_at": 1672617600000
}
```

#### Delete Document

**Endpoint:** `DELETE /api/collections/{collectionId}/documents/{documentId}`

**Response:** (204 No Content)

---

### Logs API

#### Get Recent Audit Logs

**Endpoint:** `GET /api/logs/recent`

**Query Parameters:**

- `limit`: Number of logs (default: 50, max: 1000)

**Response:**

```json
[
  {
    "id": "log_123",
    "user_id": "user_456",
    "action": "CREATE",
    "resource_type": "document",
    "resource_id": "doc_789",
    "status": "success",
    "timestamp": "2024-01-15T10:30:00Z",
    "details": "CREATE DOCUMENT in col_abc with data: {...}",
    "error_message": null
  }
]
```

---

## cURL Examples

### Login

```bash
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }' | jq '.token'
```

Save token:

```bash
TOKEN="eyJhbGciOiJIUzI1NiIs..."
```

### List Collections

```bash
curl -X GET http://localhost:8080/api/collections \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

### Create a Collection

```bash
curl -X POST http://localhost:8080/api/collections \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"posts"}' | jq '.'
```

### Create a Document

```bash
COLLECTION_ID="col_abc123"

curl -X POST http://localhost:8080/api/collections/$COLLECTION_ID/documents \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "title": "My Post",
      "content": "Hello world"
    }
  }' | jq '.'
```

### Update a Document

```bash
COLLECTION_ID="col_abc123"
DOCUMENT_ID="doc_xyz789"

curl -X PUT http://localhost:8080/api/collections/$COLLECTION_ID/documents/$DOCUMENT_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "title": "Updated Title"
    }
  }' | jq '.'
```

### Delete a Document

```bash
curl -X DELETE http://localhost:8080/api/collections/$COLLECTION_ID/documents/$DOCUMENT_ID \
  -H "Authorization: Bearer $TOKEN"
```

---

## JavaScript/Node.js

### Installation

```bash
npm install axios
```

### Basic Usage

```javascript
const axios = require("axios");

const API_URL = "http://192.168.1.100:8080";
let token = null;

// Login
async function login(email, password) {
  const response = await axios.post(`${API_URL}/auth/login`, {
    email,
    password,
  });
  token = response.data.token;
  console.log("Logged in:", response.data.user.email);
}

// Create document
async function createDocument(collectionId, data) {
  const response = await axios.post(
    `${API_URL}/api/collections/${collectionId}/documents`,
    { data },
    {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    },
  );
  return response.data;
}

// List documents
async function listDocuments(collectionId) {
  const response = await axios.get(
    `${API_URL}/api/collections/${collectionId}/documents`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
  );
  return response.data;
}

// Example usage
(async () => {
  await login("user@example.com", "password");

  const docs = await listDocuments("col_abc123");
  console.log("Documents:", docs);

  const newDoc = await createDocument("col_abc123", {
    title: "Hello",
    text: "World",
  });
  console.log("Created:", newDoc);
})();
```

---

## Python

### Installation

```bash
pip install requests
```

### Basic Usage

```python
import requests
import json

API_URL = 'http://192.168.1.100:8080'
token = None

def login(email, password):
    global token
    response = requests.post(
        f'{API_URL}/auth/login',
        json={'email': email, 'password': password}
    )
    data = response.json()
    token = data['token']
    print(f"Logged in: {data['user']['email']}")

def get_headers():
    return {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json',
    }

def list_collections():
    response = requests.get(
        f'{API_URL}/api/collections',
        headers=get_headers()
    )
    return response.json()

def create_document(collection_id, data):
    response = requests.post(
        f'{API_URL}/api/collections/{collection_id}/documents',
        headers=get_headers(),
        json={'data': data}
    )
    return response.json()

def list_documents(collection_id):
    response = requests.get(
        f'{API_URL}/api/collections/{collection_id}/documents',
        headers=get_headers()
    )
    return response.json()

# Example usage
if __name__ == '__main__':
    login('user@example.com', 'password')

    collections = list_collections()
    print(f"Collections: {json.dumps(collections, indent=2)}")

    docs = list_documents('col_abc123')
    print(f"Documents: {json.dumps(docs, indent=2)}")

    new_doc = create_document('col_abc123', {
        'title': 'Hello',
        'text': 'World'
    })
    print(f"Created: {json.dumps(new_doc, indent=2)}")
```

---

## Authentication

### Token-Based Authentication

1. **Login** with email/password to get a JWT token
2. **Include** the token in the `Authorization` header: `Bearer <token>`
3. **Token expires** after a period (check server configuration)
4. **Refresh** by logging in again

### Admin Authentication

For admin-only operations, you may also use an admin key:

```bash
curl -H "X-Admin-Key: your_secret_admin_key" ...
```

---

## Error Handling

### HTTP Status Codes

| Code | Meaning      | Action                          |
| ---- | ------------ | ------------------------------- |
| 200  | OK           | Request succeeded               |
| 201  | Created      | Resource was created            |
| 204  | No Content   | Request succeeded, no body      |
| 400  | Bad Request  | Check request format            |
| 401  | Unauthorized | Login required or token invalid |
| 403  | Forbidden    | Access denied                   |
| 404  | Not Found    | Resource doesn't exist          |
| 500  | Server Error | Try again later                 |

### Error Response Format

```json
{
  "error": "Unauthorized",
  "message": "Invalid token",
  "statusCode": 401
}
```

### Example Error Handling

**JavaScript:**

```javascript
try {
  await createDocument(collectionId, data);
} catch (error) {
  if (error.response?.status === 401) {
    console.log("Token expired, please login again");
    await login(email, password);
  } else {
    console.error("Error:", error.response?.data?.message || error.message);
  }
}
```

**Python:**

```python
try:
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
except requests.exceptions.HTTPError as e:
    if e.response.status_code == 401:
        print('Token expired, please login again')
        login(email, password)
    else:
        print(f'Error: {e.response.json()}')
```

---

## Rate Limiting & Best Practices

### Best Practices

1. **Reuse tokens** - Don't login for every request
2. **Batch operations** - Combine multiple operations when possible
3. **Connection pooling** - Keep HTTP connections open
4. **Error handling** - Implement retry logic with exponential backoff
5. **Offline support** - Cache data locally when possible

### Example: Batch Operations with Retry

**JavaScript:**

```javascript
async function withRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      const delay = Math.pow(2, i) * 100; // Exponential backoff
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

// Usage
const result = await withRetry(() => createDocument(collectionId, data));
```

### Logging Audit Trail

All operations are logged. View logs:

```bash
# Using CLI
dart cli_client/bin/client.dart --server http://localhost:8080 --view-logs 100

# Using API
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/logs/recent?limit=100 | jq '.'
```

---

## Support & Resources

- **Backend Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Operator Manual**: See [OPERATOR_MANUAL.md](OPERATOR_MANUAL.md)
- **Flutter SDK**: See [FLUTTER_SDK_GUIDE.md](FLUTTER_SDK_GUIDE.md)
- **CLI Client**: See [../cli_client/README.md](../cli_client/README.md)
