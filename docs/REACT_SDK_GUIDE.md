# Shadow App Backend - React SDK Guide

**Version:** 0.1.0  
**Package:** `@shadow-app/react-sdk`  
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
9. [React Hooks Reference](#react-hooks-reference)
10. [TypeScript Types](#typescript-types)
11. [Error Handling](#error-handling)
12. [Best Practices](#best-practices)
13. [Comparison with Flutter SDK](#comparison-with-flutter-sdk)

---

## Overview

The Shadow App React SDK is a type-safe, React-friendly client library for integrating with the Shadow App Dart Backend Server. It provides a complete set of tools for modern React applications including:

- 🔐 **Authentication** - JWT-based auth with automatic token refresh
- 📄 **Document CRUD** - Full create, read, update, delete operations
- 📁 **Media Handling** - File upload/download with metadata
- ⚛️ **React Hooks** - Pre-built hooks for common patterns
- 🎯 **Context Provider** - Centralized client management
- 📦 **TypeScript** - Full type safety and IntelliSense support
- ⚡ **Auto Retry** - Automatic token refresh on 401 errors
- 🛠️ **Developer Friendly** - Intuitive API design

### Why Use the React SDK?

For **React developers**, this SDK provides:

- React hooks that integrate with your component state
- Context Provider for dependency injection
- TypeScript definitions for type safety
- Familiar patterns (useState, useEffect)

For **Web developers**, this SDK provides:

- Pure JavaScript/TypeScript client (works without React)
- Axios-based HTTP client with interceptors
- Promise-based async API
- Browser-compatible (File API, Blob support)

---

## Installation

### NPM

```bash
npm install @shadow-app/react-sdk
```

### Yarn

```bash
yarn add @shadow-app/react-sdk
```

### PNPM

```bash
pnpm add @shadow-app/react-sdk
```

### Peer Dependencies

The SDK requires React 18+ as a peer dependency:

```json
{
  "peerDependencies": {
    "react": "^18.0.0 || ^19.0.0"
  }
}
```

### CDN (For Quick Testing)

```html
<!-- Not recommended for production -->
<script src="https://unpkg.com/@shadow-app/react-sdk@latest/dist/index.js"></script>
```

---

## Quick Start

### Method 1: Using Context Provider (Recommended)

This is the **recommended approach** for React applications.

#### Step 1: Wrap Your App

```tsx
// src/App.tsx
import React from "react";
import { ShadowAppProvider } from "@shadow-app/react-sdk";
import { Dashboard } from "./Dashboard";

export default function App() {
  return (
    <ShadowAppProvider
      config={{
        baseURL: "http://localhost:8080",
        onAuthError: () => {
          // Redirect to login on auth failure
          window.location.href = "/login";
        },
        onTokenRefresh: (token) => {
          // Optional: Store token for persistence
          localStorage.setItem("accessToken", token);
        },
      }}
    >
      <Dashboard />
    </ShadowAppProvider>
  );
}
```

#### Step 2: Use Hooks in Components

```tsx
// src/components/LoginForm.tsx
import React, { useState } from "react";
import { useShadowApp, useAuth } from "@shadow-app/react-sdk";

export function LoginForm() {
  const { client } = useShadowApp();
  const { login, isLoading, error } = useAuth(client);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await login({ email, password });
  };

  return (
    <form onSubmit={handleSubmit}>
      <h2>Login</h2>

      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />

      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
        required
      />

      <button type="submit" disabled={isLoading}>
        {isLoading ? "Logging in..." : "Login"}
      </button>

      {error && <p style={{ color: "red" }}>Error: {error.error}</p>}
    </form>
  );
}
```

### Method 2: Direct Client Usage (Without React)

For vanilla JavaScript/TypeScript or non-React frameworks:

```typescript
import { ShadowAppClient } from "@shadow-app/react-sdk";

// Create client
const client = new ShadowAppClient({
  baseURL: "http://localhost:8080",
  timeout: 30000,
});

// Login
const authResponse = await client.login({
  email: "user@example.com",
  password: "password123",
});

console.log("Logged in as:", authResponse.data.user.email);

// Create a document
const doc = await client.createDocument("notes", {
  data: { title: "My First Note", content: "Hello world!" },
});

console.log("Created document:", doc);
```

---

## SDK Architecture

### File Structure

```
react_sdk/
├── src/
│   ├── index.ts          # Main exports
│   ├── types.ts          # TypeScript type definitions
│   ├── client.ts         # Core API client (axios-based)
│   ├── hooks.tsx         # React hooks (useAuth, useDocuments, etc.)
│   └── context.tsx       # React Context Provider
├── package.json          # NPM package configuration
├── tsconfig.json         # TypeScript configuration
└── README.md             # Basic documentation
```

### Architecture Components

1. **ShadowAppClient** (`client.ts`)
   - Core HTTP client using axios
   - Token management and refresh logic
   - All API methods (auth, CRUD, media)

2. **React Hooks** (`hooks.tsx`)
   - `useAuth` - Authentication state management
   - `useDocument` - Single document operations
   - `useDocuments` - Collection document list with CRUD
   - `useMediaUpload` - File upload with progress
   - `useMedia` - Media download and metadata
   - `useHealthCheck` - Server health monitoring

3. **Context Provider** (`context.tsx`)
   - `ShadowAppProvider` - Wraps your app
   - `useShadowApp` - Access client from anywhere

4. **TypeScript Types** (`types.ts`)
   - All interface definitions
   - Request/response types
   - Configuration types

---

## Configuration

### ShadowAppConfig Interface

```typescript
interface ShadowAppConfig {
  baseURL: string; // Required: Backend server URL
  apiKey?: string; // Optional: API key for requests
  timeout?: number; // Optional: Request timeout (ms), default 30000
  onTokenRefresh?: (token: string) => void; // Optional: Called when token refreshes
  onAuthError?: () => void; // Optional: Called on auth failure
}
```

### Configuration Examples

#### Basic Configuration

```typescript
const config = {
  baseURL: "http://localhost:8080",
};
```

#### Production Configuration

```typescript
const config = {
  baseURL: process.env.REACT_APP_API_URL || "https://api.myapp.com",
  timeout: 60000, // 60 seconds for slow networks
  onTokenRefresh: (token) => {
    // Persist token to localStorage
    localStorage.setItem("shadowapp_access_token", token);
    console.log("Token refreshed successfully");
  },
  onAuthError: () => {
    // Clear local storage and redirect
    localStorage.clear();
    window.location.href = "/login";
  },
};
```

#### Development Configuration with Debugging

```typescript
const config = {
  baseURL: "http://192.168.1.100:8080", // Local network IP
  timeout: 5000, // Short timeout for fast failure
  onTokenRefresh: (token) => {
    console.log("🔄 Token refreshed:", token.substring(0, 20) + "...");
  },
  onAuthError: () => {
    console.error("❌ Auth error - redirecting to login");
    alert("Session expired. Please log in again.");
  },
};
```

---

## Authentication

### Signup

Create a new user account:

```tsx
import { useShadowApp, useAuth } from "@shadow-app/react-sdk";

function SignupForm() {
  const { client } = useShadowApp();
  const { signup, isLoading, error } = useAuth(client);

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      await signup({
        email: "newuser@example.com",
        password: "SecurePass123!",
      });

      // User is now logged in automatically
      console.log("Signup successful!");
    } catch (err) {
      console.error("Signup failed:", err);
    }
  };

  return (
    <form onSubmit={handleSignup}>
      {/* form fields */}
      <button type="submit" disabled={isLoading}>
        {isLoading ? "Creating account..." : "Sign Up"}
      </button>
      {error && <p>Error: {error.error}</p>}
    </form>
  );
}
```

### Login

Authenticate existing user:

```tsx
function LoginForm() {
  const { client } = useShadowApp();
  const { user, login, isLoading, error } = useAuth(client);

  const handleLogin = async (email: string, password: string) => {
    await login({ email, password });
  };

  if (user) {
    return <p>Welcome, {user.email}!</p>;
  }

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        handleLogin(emailValue, passwordValue);
      }}
    >
      {/* form fields */}
    </form>
  );
}
```

### Logout

```tsx
function LogoutButton() {
  const { client } = useShadowApp();
  const { logout } = useAuth(client);

  const handleLogout = () => {
    logout();
    // Tokens are cleared, user is logged out
  };

  return <button onClick={handleLogout}>Logout</button>;
}
```

### Manual Token Management

For advanced use cases:

```typescript
import { ShadowAppClient } from "@shadow-app/react-sdk";

const client = new ShadowAppClient({ baseURL: "http://localhost:8080" });

// Set tokens from storage
const accessToken = localStorage.getItem("access_token");
const refreshToken = localStorage.getItem("refresh_token");

if (accessToken && refreshToken) {
  client.setTokens({ accessToken, refreshToken });
}

// Check authentication status
if (client.isAuthenticated()) {
  console.log("User is authenticated");
}

// Get current access token
const token = client.getAccessToken();

// Manually refresh token
const newToken = await client.refreshAccessToken();
```

### Persistent Authentication

Restore session on page reload:

```tsx
import React, { useEffect } from "react";
import { ShadowAppProvider, useShadowApp } from "@shadow-app/react-sdk";

function App() {
  return (
    <ShadowAppProvider config={{ baseURL: "http://localhost:8080" }}>
      <AuthManager>
        <Dashboard />
      </AuthManager>
    </ShadowAppProvider>
  );
}

function AuthManager({ children }: { children: React.ReactNode }) {
  const { client } = useShadowApp();

  useEffect(() => {
    // Restore tokens from localStorage
    const accessToken = localStorage.getItem("access_token");
    const refreshToken = localStorage.getItem("refresh_token");

    if (accessToken && refreshToken) {
      client.setTokens({ accessToken, refreshToken });
    }
  }, [client]);

  return <>{children}</>;
}
```

---

## Document Operations

### Create Document

```tsx
import { useShadowApp, useDocuments } from "@shadow-app/react-sdk";

function CreateNoteForm() {
  const { client } = useShadowApp();
  const { createDocument, isLoading } = useDocuments(client, "notes");

  const handleCreate = async () => {
    const newDoc = await createDocument({
      data: {
        title: "My New Note",
        content: "This is the content",
        tags: ["react", "typescript"],
        createdDate: new Date().toISOString(),
      },
    });

    console.log("Created:", newDoc.id);
  };

  return (
    <button onClick={handleCreate} disabled={isLoading}>
      {isLoading ? "Creating..." : "Create Note"}
    </button>
  );
}
```

### Read Document

```tsx
function DocumentViewer({ documentId }: { documentId: string }) {
  const { client } = useShadowApp();
  const { document, isLoading, error, refetch } = useDocument(
    client,
    "notes",
    documentId,
  );

  if (isLoading) return <p>Loading document...</p>;
  if (error) return <p>Error: {error.error}</p>;
  if (!document) return <p>Document not found</p>;

  return (
    <div>
      <h2>{document.data.title}</h2>
      <p>{document.data.content}</p>
      <button onClick={refetch}>Refresh</button>
    </div>
  );
}
```

### Update Document

```tsx
function EditDocumentForm({ documentId }: { documentId: string }) {
  const { client } = useShadowApp();
  const { document, updateDocument, isLoading } = useDocument(
    client,
    "notes",
    documentId,
  );

  const handleSave = async (newTitle: string, newContent: string) => {
    await updateDocument({
      data: {
        ...document!.data,
        title: newTitle,
        content: newContent,
        lastModified: new Date().toISOString(),
      },
    });
  };

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        handleSave(titleValue, contentValue);
      }}
    >
      {/* form fields */}
      <button type="submit" disabled={isLoading}>
        {isLoading ? "Saving..." : "Save"}
      </button>
    </form>
  );
}
```

### Delete Document

```tsx
function DocumentList() {
  const { client } = useShadowApp();
  const { documents, deleteDocument, isLoading } = useDocuments(
    client,
    "notes",
  );

  const handleDelete = async (docId: string) => {
    if (confirm("Are you sure?")) {
      await deleteDocument(docId);
      // Document is removed from local state automatically
    }
  };

  return (
    <ul>
      {documents.map((doc) => (
        <li key={doc.id}>
          {doc.data.title}
          <button onClick={() => handleDelete(doc.id)}>Delete</button>
        </li>
      ))}
    </ul>
  );
}
```

### List DocumentsFunction DocumentsList() {

const { client } = useShadowApp();
const {
documents,
isLoading,
error,
hasMore,
loadMore,
} = useDocuments(client, "notes", {
autoLoad: true,
limit: 20,
});

if (isLoading && documents.length === 0) {
return <p>Loading documents...</p>;
}

return (
<div>
<h2>Notes ({documents.length})</h2>

      {documents.map((doc) => (
        <div key={doc.id} style={{ padding: "10px", border: "1px solid #ccc" }}>
          <h3>{doc.data.title}</h3>
          <p>{doc.data.content}</p>
          <small>Created: {new Date(doc.createdAt).toLocaleString()}</small>
        </div>
      ))}

      {hasMore && (
        <button onClick={loadMore} disabled={isLoading}>
          {isLoading ? "Loading..." : "Load More"}
        </button>
      )}

      {error && <p>Error: {error.error}</p>}
    </div>

);
}

````

### Pagination

```tsx
function PaginatedDocuments() {
  const { client } = useShadowApp();
  const [page, setPage] = useState(0);
  const limit = 10;

  const { documents, isLoading, total } = useDocuments(
    client,
    "notes",
    {
      autoLoad: true,
      limit: limit,
      offset: page * limit,
    }
  );

  const totalPages = Math.ceil(total / limit);

  return (
    <div>
      {documents.map((doc) => (
        <div key={doc.id}>{doc.data.title}</div>
      ))}

      <div>
        <button
          onClick={() => setPage(p => Math.max(0, p - 1))}
          disabled={page === 0}
        >
          Previous
        </button>

        <span> Page {page + 1} of {totalPages} </span>

        <button
          onClick={() => setPage(p => p + 1)}
          disabled={page >= totalPages - 1}
        >
          Next
        </button>
      </div>
    </div>
  );
}
````

---

## Media Handling

### Upload File with Progress

```tsx
import { useShadowApp, useMediaUpload } from "@shadow-app/react-sdk";

function FileUploader() {
  const { client } = useShadowApp();
  const { upload, isUploading, progress, error, result } =
    useMediaUpload(client);

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const uploadResult = await upload({
      file,
      filename: file.name,
    });

    if (uploadResult) {
      console.log("Uploaded! Media ID:", uploadResult.data.mediaId);
    }
  };

  return (
    <div>
      <input type="file" onChange={handleFileSelect} disabled={isUploading} />

      {isUploading && (
        <div>
          <progress value={progress} max={100} />
          <span>{progress.toFixed(0)}%</span>
        </div>
      )}

      {error && <p>Upload failed: {error.error}</p>}

      {result && <p>✅ Upload complete! ID: {result.data.mediaId}</p>}
    </div>
  );
}
```

### Download File

```tsx
function ImageDownloader({ mediaId }: { mediaId: string }) {
  const { client } = useShadowApp();
  const { download, isLoading, error, blob } = useMedia(client, mediaId);

  useEffect(() => {
    download();
  }, [mediaId]);

  if (isLoading) return <p>Loading image...</p>;
  if (error) return <p>Error: {error.error}</p>;
  if (!blob) return null;

  const url = URL.createObjectURL(blob);

  return (
    <div>
      <img src={url} alt="Downloaded media" style={{ maxWidth: "100%" }} />
      <a href={url} download="image.jpg">
        Download
      </a>
    </div>
  );
}
```

### Get Media Metadata

```tsx
function MediaInfo({ mediaId }: { mediaId: string }) {
  const { client } = useShadowApp();
  const { metadata, isLoading, getMetadata } = useMedia(client, mediaId);

  useEffect(() => {
    getMetadata();
  }, [mediaId]);

  if (isLoading) return <p>Loading...</p>;
  if (!metadata) return null;

  return (
    <div>
      <h3>Media Information</h3>
      <p>
        <strong>Filename:</strong> {metadata.filename}
      </p>
      <p>
        <strong>Type:</strong> {metadata.mimeType}
      </p>
      <p>
        <strong>Size:</strong> {(metadata.size / 1024).toFixed(2)} KB
      </p>
      <p>
        <strong>Uploaded:</strong>{" "}
        {new Date(metadata.uploadedAt).toLocaleString()}
      </p>
    </div>
  );
}
```

### Image Gallery Example

```tsx
function ImageGallery() {
  const { client } = useShadowApp();
  const { upload, isUploading } = useMediaUpload(client);
  const { documents } = useDocuments(client, "gallery");

  const handleUpload = async (file: File) => {
    const result = await upload({ file });

    if (result) {
      // Save media ID to a document
      await client.createDocument("gallery", {
        data: {
          mediaId: result.data.mediaId,
          filename: file.name,
          uploadedAt: new Date().toISOString(),
        },
      });
    }
  };

  return (
    <div>
      <h2>Image Gallery</h2>

      <input
        type="file"
        accept="image/*"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleUpload(file);
        }}
        disabled={isUploading}
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gap: "10px",
        }}
      >
        {documents.map((doc) => (
          <ImageThumbnail key={doc.id} mediaId={doc.data.mediaId} />
        ))}
      </div>
    </div>
  );
}

function ImageThumbnail({ mediaId }: { mediaId: string }) {
  const { client } = useShadowApp();
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  useEffect(() => {
    client.downloadMedia(mediaId).then((blob) => {
      setImageUrl(URL.createObjectURL(blob));
    });
  }, [mediaId]);

  if (!imageUrl) return <div>Loading...</div>;

  return <img src={imageUrl} alt="Gallery item" style={{ width: "100%" }} />;
}
```

---

## React Hooks Reference

### useAuth

Manages authentication state.

```typescript
interface UseAuthReturn {
  user: User | null; // Current user or null
  isAuthenticated: boolean; // Auth status
  isLoading: boolean; // Loading state
  error: ApiError | null; // Last error
  signup: (req: SignupRequest) => Promise<void>;
  login: (req: LoginRequest) => Promise<void>;
  logout: () => void;
}

const auth = useAuth(client);
```

### useDocument

Manages a single document.

```typescript
interface UseDocumentReturn {
  document: Document | null; // The document
  isLoading: boolean; // Loading state
  error: ApiError | null; // Last error
  updateDocument: (req: UpdateDocumentRequest) => Promise<void>;
  deleteDocument: () => Promise<void>;
  refetch: () => Promise<void>;
}

const doc = useDocument(client, collectionId, documentId, { autoLoad: true });
```

### useDocuments

Manages a collection of documents.

```typescript
interface UseDocumentsOptions {
  autoLoad?: boolean; // Auto-fetch on mount
  limit?: number; // Page size
  offset?: number; // Pagination offset
}

interface UseDocumentsReturn {
  documents: Document[]; // List of documents
  total: number; // Total count
  isLoading: boolean; // Loading state
  error: ApiError | null; // Last error
  createDocument: (req: CreateDocumentRequest) => Promise<Document | null>;
  updateDocument: (id: string, req: UpdateDocumentRequest) => Promise<void>;
  deleteDocument: (id: string) => Promise<void>;
  refetch: () => Promise<void>;
  loadMore: () => Promise<void>;
  hasMore: boolean; // More pages available
}

const docs = useDocuments(client, collectionId, options);
```

### useMediaUpload

Handles file uploads with progress.

```typescript
interface UseMediaUploadReturn {
  upload: (req: UploadMediaRequest) => Promise<UploadMediaResponse | null>;
  isUploading: boolean; // Upload in progress
  progress: number; // 0-100
  error: ApiError | null; // Last error
  result: UploadMediaResponse | null; // Upload result
}

const media = useMediaUpload(client);
```

### useMedia

Downloads media and fetches metadata.

```typescript
interface UseMediaReturn {
  blob: Blob | null; // Downloaded file
  metadata: MediaMetadata | null; // File metadata
  isLoading: boolean; // Loading state
  error: ApiError | null; // Last error
  download: () => Promise<void>;
  getMetadata: () => Promise<void>;
}

const media = useMedia(client, mediaId);
```

### useHealthCheck

Monitors server health.

```typescript
interface UseHealthCheckReturn {
  isHealthy: boolean; // Server status
  isChecking: boolean; // Check in progress
  error: ApiError | null; // Last error
  lastCheck: Date | null; // Last check time
  checkHealth: () => Promise<void>;
}

const health = useHealthCheck(client, { interval: 30000 }); // Check every 30s
```

---

## TypeScript Types

### Core Types

```typescript
// User
interface User {
  id: string;
  email: string;
  role: "user" | "admin";
  createdAt: string;
}

// Document
interface Document {
  id: string;
  collectionId: string;
  ownerId: string;
  data: Record<string, any>; // Your custom data
  createdAt: string;
  updatedAt: string;
}

// Collection
interface Collection {
  id: string;
  name: string;
  ownerId: string;
  rules: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

// Media
interface MediaMetadata {
  id: string;
  uploaderId: string;
  filename: string;
  mimeType: string;
  size: number; // Bytes
  uploadedAt: string;
}
```

### Request Types

```typescript
interface SignupRequest {
  email: string;
  password: string;
}

interface LoginRequest {
  email: string;
  password: string;
}

interface CreateDocumentRequest {
  data: Record<string, any>;
}

interface UpdateDocumentRequest {
  data: Record<string, any>;
}

interface UploadMediaRequest {
  file: File;
  filename?: string;
}
```

### Response Types

```typescript
interface AuthResponse {
  success: boolean;
  data: {
    user: User;
    accessToken: string;
    refreshToken: string;
  };
}

interface ListDocumentsResponse {
  success: boolean;
  data: {
    documents: Document[];
    total: number;
    limit: number;
    offset: number;
  };
}

interface UploadMediaResponse {
  success: boolean;
  data: {
    mediaId: string;
    metadata: MediaMetadata;
  };
}
```

### Error Type

```typescript
interface ApiError {
  error: string;
  message?: string;
  statusCode?: number;
}
```

---

## Error Handling

### Global Error Handler

```tsx
function App() {
  const handleAuthError = () => {
    console.error("Authentication failed");
    localStorage.clear();
    window.location.href = "/login";
  };

  return (
    <ShadowAppProvider
      config={{
        baseURL: "http://localhost:8080",
        onAuthError: handleAuthError,
      }}
    >
      <YourApp />
    </ShadowAppProvider>
  );
}
```

### Component-Level Error Handling

```tsx
function DocumentOperations() {
  const { client } = useShadowApp();
  const { documents, error, createDocument } = useDocuments(client, "notes");

  const handleCreate = async () => {
    try {
      await createDocument({ data: { title: "New Note" } });
    } catch (err) {
      if (err instanceof Error) {
        alert(`Failed to create document: ${err.message}`);
      }
    }
  };

  // Display error from hook
  if (error) {
    return (
      <div style={{ color: "red" }}>
        <h3>Error</h3>
        <p>{error.error}</p>
        {error.message && <p>{error.message}</p>}
      </div>
    );
  }

  return <div>{/* normal UI */}</div>;
}
```

### Network Error Handling

```tsx
import axios from "axios";

const { client } = useShadowApp();

try {
  await client.login({ email, password });
} catch (error) {
  if (axios.isAxiosError(error)) {
    if (error.response) {
      // Server responded with error status
      console.log("Status:", error.response.status);
      console.log("Data:", error.response.data);
    } else if (error.request) {
      // Request made but no response
      console.log("No response from server");
      alert("Server is not responding. Please check your connection.");
    } else {
      // Request setup error
      console.log("Error:", error.message);
    }
  }
}
```

---

## Best Practices

### 1. Use Context Provider

✅ **Do:**

```tsx
<ShadowAppProvider config={{ baseURL: "..." }}>
  <App />
</ShadowAppProvider>
```

❌ **Don't:**

```tsx
// Creating multiple clients
const client1 = new ShadowAppClient(...);
const client2 = new ShadowAppClient(...);
```

### 2. Handle Loading States

✅ **Do:**

```tsx
const { documents, isLoading } = useDocuments(client, "notes");

if (isLoading) return <LoadingSpinner />;
return <DocumentList documents={documents} />;
```

❌ **Don't:**

```tsx
// Assuming data is always available
return documents.map(...); // May crash if documents = []
```

### 3. Clean Up Blob URLs

✅ **Do:**

```tsx
useEffect(() => {
  const url = URL.createObjectURL(blob);
  setImageUrl(url);

  return () => URL.revokeObjectURL(url); // Clean up
}, [blob]);
```

❌ **Don't:**

```tsx
// Creating blob URLs without cleanup causes memory leaks
const url = URL.createObjectURL(blob);
```

### 4. Implement Token Persistence

✅ **Do:**

```tsx
const config = {
  baseURL: "http://localhost:8080",
  onTokenRefresh: (token) => {
    localStorage.setItem("access_token", token);
  },
};

// Restore on app start
useEffect(() => {
  const token = localStorage.getItem("access_token");
  const refresh = localStorage.getItem("refresh_token");
  if (token && refresh) {
    client.setTokens({ accessToken: token, refreshToken: refresh });
  }
}, []);
```

### 5. Validate User Input

✅ **Do:**

```tsx
const handleCreate = async () => {
  if (!title.trim()) {
    setError("Title is required");
    return;
  }

  if (title.length > 100) {
    setError("Title too long");
    return;
  }

  await createDocument({ data: { title } });
};
```

### 6. Optimize Re-renders

✅ **Do:**

```tsx
const { createDocument } = useDocuments(client, "notes");

// createDocument is memoized, won't cause re-renders
<button onClick={() => createDocument(...)}>Create</button>
```

### 7. Handle Race Conditions

✅ **Do:**

```tsx
useEffect(() => {
  let cancelled = false;

  async function fetchData() {
    const data = await client.getDocument(collectionId, docId);
    if (!cancelled) {
      setDocument(data);
    }
  }

  fetchData();

  return () => {
    cancelled = true; // Ignore results if component unmounts
  };
}, [docId]);
```

---

## Comparison with Flutter SDK

Both SDKs provide **identical features** but with different architectural approaches:

### File Count Comparison

| SDK             | Files   | Reason                                                        |
| --------------- | ------- | ------------------------------------------------------------- |
| **React SDK**   | 8 files | TypeScript types, React hooks, Context Provider, build config |
| **Flutter SDK** | 5 files | Dart types inline, service classes, simpler config            |

### Architecture Comparison

**React SDK Philosophy:**

- Separation of concerns (types, client, hooks, context)
- Functional programming with hooks
- Context API for dependency injection
- TypeScript for type safety

**Flutter SDK Philosophy:**

- Object-oriented service classes
- Singleton pattern with static methods
- Types live with implementation
- Dart's built-in type system

### Feature Parity

| Feature                | React SDK     | Flutter SDK                 |
| ---------------------- | ------------- | --------------------------- |
| Authentication         | ✅            | ✅                          |
| CRUD Operations        | ✅            | ✅                          |
| Media Upload/Download  | ✅            | ✅                          |
| Token Refresh          | ✅ Automatic  | ✅ Automatic                |
| TypeScript/Type Safety | ✅ TypeScript | ✅ Dart                     |
| State Management       | ✅ Hooks      | ✅ Built-in                 |
| Offline Support        | ❌            | ✅ (with SharedPreferences) |

### Code Comparison

**React SDK:**

```tsx
// Setup
<ShadowAppProvider config={{ baseURL: "..." }}>
  <App />
</ShadowAppProvider>;

// Usage
const { documents, createDocument } = useDocuments(client, "notes");
await createDocument({ data: { title: "Note" } });
```

**Flutter SDK:**

```dart
// Setup
await ShadowApp.initialize(serverUrl: "...");

// Usage
final doc = await ShadowApp.collection('notes').create({'title': 'Note'});
```

### When to Use Each

**Use React SDK when:**

- Building web applications
- Working with React/Next.js/Remix
- Need browser-based file handling
- TypeScript is your primary language

**Use Flutter SDK when:**

- Building mobile apps (iOS/Android)
- Building desktop apps (Windows/Mac/Linux)
- Need offline-first capabilities
- Dart/Flutter is your primary framework

---

## Additional Resources

### Documentation

- [CLI Audit Report](./CLI_AUDIT_REPORT.md) - CLI refactoring details
- [Flutter SDK Guide](./FLUTTER_SDK_GUIDE.md) - Flutter SDK documentation
- [Architecture](./ARCHITECTURE.md) - Backend architecture overview
- [Operator Manual](./OPERATOR_MANUAL.md) - Server operation guide

### Examples

See the React SDK README at `/react_sdk/README.md` for additional code examples.

### Support

For issues, questions, or contributions:

- **Repository:** miranda6424/dartBackendServer
- **Branch:** devGrace (development)
- **Backend Version:** 0.1.0
- **SDK Version:** 0.1.0

---

**Guide Version:** 1.0  
**Last Updated:** March 8, 2026  
**Maintainer:** Shadow App Team
