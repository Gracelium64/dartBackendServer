# Shadow App React SDK

React SDK for easy integration with the Shadow App Dart Backend Server. Provides type-safe API client, React hooks, and context provider for seamless integration into React applications.

## Features

- 🔐 **Authentication** - Signup, login, logout with automatic token refresh
- 📄 **Document CRUD** - Create, read, update, delete documents in collections
- 📁 **Media Handling** - Upload and download files with metadata
- ⚛️ **React Hooks** - Ready-to-use hooks for common operations
- 🔄 **Auto Token Refresh** - Automatic JWT token refresh on expiration
- 📦 **TypeScript** - Full TypeScript support with type definitions
- ⚡ **Context Provider** - Share client instance across your app

## Backend Operator Notes

The backend now includes additional operator-only account maintenance and reporting features that affect React clients indirectly:

- Operators can change a user's login email from the admin console.
- Operators can reset a user's password with hashing, using either manual entry or a generated random password.
- Operators can configure a Gmail sender account and email full admin report bundles, or export the same bundle locally.

What this means for React apps:

- Users may need to log in with a different email after an operator account update.
- Password resets happen on the backend; the React SDK does not expose a client-side admin reset API.
- Existing tokens continue to work until expiry, after which re-authentication uses the new credentials.

## Installation

```bash
npm install @shadow-app/react-sdk
# or
yarn add @shadow-app/react-sdk
# or
pnpm add @shadow-app/react-sdk
```

## Quick Start

### 1. Setup Provider (Recommended)

Wrap your app with `ShadowAppProvider`:

```tsx
import { ShadowAppProvider } from "@shadow-app/react-sdk";

function App() {
  return (
    <ShadowAppProvider
      config={{
        baseURL: "http://localhost:8080",
        onAuthError: () => {
          // Handle auth errors (e.g., redirect to login)
          console.log("Authentication failed");
        },
      }}
    >
      <YourApp />
    </ShadowAppProvider>
  );
}
```

### 2. Use Hooks in Components

```tsx
import { useShadowApp, useAuth, useDocuments } from "@shadow-app/react-sdk";

function LoginForm() {
  const { client } = useShadowApp();
  const { login, isLoading, error } = useAuth(client);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await login({
        email: "user@example.com",
        password: "password123",
      });
    } catch (err) {
      console.error("Login failed:", err);
    }
  };

  return (
    <form onSubmit={handleLogin}>
      {/* form fields */}
      <button type="submit" disabled={isLoading}>
        {isLoading ? "Logging in..." : "Login"}
      </button>
      {error && <p>Error: {error.error}</p>}
    </form>
  );
}

function DocumentsList() {
  const { client } = useShadowApp();
  const { documents, isLoading, createDocument, deleteDocument } = useDocuments(
    client,
    "my-collection",
  );

  if (isLoading) return <p>Loading...</p>;

  return (
    <div>
      {documents.map((doc) => (
        <div key={doc.id}>
          <pre>{JSON.stringify(doc.data, null, 2)}</pre>
          <button onClick={() => deleteDocument(doc.id)}>Delete</button>
        </div>
      ))}
      <button onClick={() => createDocument({ data: { title: "New Doc" } })}>
        Add Document
      </button>
    </div>
  );
}
```

## API Reference

### Client

#### Creating a Client

```tsx
import { ShadowAppClient } from "@shadow-app/react-sdk";

const client = new ShadowAppClient({
  baseURL: "http://localhost:8080",
  timeout: 30000, // optional, default 30s
  onTokenRefresh: (token) => {
    // Called when token is refreshed
    localStorage.setItem("token", token);
  },
  onAuthError: () => {
    // Called when auth fails
    window.location.href = "/login";
  },
});
```

#### Authentication Methods

```tsx
// Signup
const response = await client.signup({
  email: "user@example.com",
  password: "securePassword123",
});

// Login
const response = await client.login({
  email: "user@example.com",
  password: "securePassword123",
});

// Logout
client.logout();

// Manual token management
client.setToken("xxx");
const token = client.getAccessToken();
const isAuth = client.isAuthenticated();
```

#### Document Methods

```tsx
// Create document
const doc = await client.createDocument("collection-id", {
  data: { title: "My Document", content: "Hello world" },
});

// Get document
const doc = await client.getDocument("collection-id", "document-id");

// Update document
const updated = await client.updateDocument("collection-id", "document-id", {
  data: { title: "Updated Title" },
});

// Delete document
await client.deleteDocument("collection-id", "document-id");

// List documents
const response = await client.listDocuments("collection-id", {
  limit: 20,
  offset: 0,
});
```

#### Media Methods

```tsx
// Upload file
const fileInput = document.querySelector('input[type="file"]');
const file = fileInput.files[0];

const response = await client.uploadMedia({
  file: file,
  filename: "my-image.jpg", // optional
  destinationCollection: "my-collection", // required: collection to associate media with
  destinationDocId: "document-id", // required: document to associate media with
});
const mediaId = response.data.id;

// Download file
const blob = await client.downloadMedia(mediaId);
const url = URL.createObjectURL(blob);

// Get metadata
const metadata = await client.getMediaMetadata(mediaId);

// Get direct download URL
const url = client.getMediaUrl(mediaId);
```

### Hooks

#### useAuth

Manage authentication state:

```tsx
const {
  user, // Current user or null
  isAuthenticated, // Boolean auth status
  isLoading, // Loading state
  error, // Error if any
  signup, // Signup function
  login, // Login function
  logout, // Logout function
} = useAuth(client);
```

#### useDocument

Fetch a single document:

```tsx
const {
  document, // Document or null
  isLoading, // Loading state
  error, // Error if any
  refetch, // Refetch function
} = useDocument(client, "collection-id", "document-id");
```

#### useDocuments

Manage documents in a collection:

```tsx
const {
  documents, // Array of documents
  total, // Total count
  isLoading, // Loading state
  error, // Error if any
  refetch, // Refetch function
  createDocument, // Create new document
  updateDocument, // Update existing document
  deleteDocument, // Delete document
} = useDocuments(client, "collection-id", { limit: 50 });
```

#### useMediaUpload

Upload media files:

```tsx
const {
  uploadMedia, // Upload function (returns mediaId)
  isUploading, // Upload in progress
  progress, // Upload progress (0-100)
  error, // Error if any
} = useMediaUpload(client);

// Usage
const handleFileChange = async (e) => {
  const file = e.target.files[0];
  const mediaId = await uploadMedia({
    file,
    destinationCollection: "my-collection", // required
    destinationDocId: "document-id", // required
  });
  console.log("Uploaded:", mediaId);
};
```

#### useMedia

Access media files:

```tsx
const {
  metadata, // MediaMetadata or null
  isLoading, // Loading state
  error, // Error if any
  download, // Download function (returns Blob)
  getUrl, // Get direct URL
} = useMedia(client, mediaId);
```

#### useHealthCheck

Monitor server health:

```tsx
const {
  status, // 'ok' or null
  isHealthy, // Boolean health status
  isChecking, // Checking in progress
  error, // Error if any
  check, // Manual check function
} = useHealthCheck(client, 30000); // Check every 30s
```

## Advanced Usage

### Manual Client Usage (Without Provider)

```tsx
import { ShadowAppClient, useAuth } from "@shadow-app/react-sdk";

function App() {
  const [client] = useState(
    () => new ShadowAppClient({ baseURL: "http://localhost:8080" }),
  );

  return <LoginForm client={client} />;
}

function LoginForm({ client }: { client: ShadowAppClient }) {
  const { login } = useAuth(client);
  // ...
}
```

### Persistent Authentication

Store tokens in localStorage:

```tsx
const client = new ShadowAppClient({
  baseURL: "http://localhost:8080",
  onTokenRefresh: (token) => {
    // Save latest token to localStorage
    localStorage.setItem("token", token);
  },
});

// Restore token on app load
const savedToken = localStorage.getItem("token");
if (savedToken) {
  client.setToken(savedToken);
}
```

### Error Handling

```tsx
try {
  await client.createDocument('collection-id', { data: { ... } });
} catch (error) {
  if (error.statusCode === 403) {
    console.log('Permission denied');
  } else if (error.statusCode === 401) {
    console.log('Not authenticated');
  } else {
    console.log('Error:', error.error);
  }
}
```

### File Download with Progress

```tsx
async function downloadWithProgress(mediaId: string) {
  const blob = await client.downloadMedia(mediaId);

  // Create download link
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "file.pdf";
  a.click();

  // Cleanup
  URL.revokeObjectURL(url);
}
```

## TypeScript Support

Full TypeScript support with exported types:

```tsx
import type {
  ShadowAppConfig,
  User,
  Document,
  Collection,
  MediaMetadata,
  ApiError,
  // ... and more
} from "@shadow-app/react-sdk";
```

## Best Practices

1. **Use Context Provider** - Wrap your app with `ShadowAppProvider` to share the client instance
2. **Handle Auth Errors** - Implement `onAuthError` callback for global auth error handling
3. **Persist Tokens** - Save tokens to localStorage/sessionStorage for persistent authentication
4. **Error Boundaries** - Wrap components with React error boundaries to catch API errors
5. **Loading States** - Always show loading indicators using the `isLoading` state from hooks
6. **Cleanup** - Hooks automatically cleanup, but manual subscriptions should be cleaned up

## Examples

Check the `/examples` directory for complete example applications:

- Basic authentication flow
- Document CRUD operations
- File upload/download
- Real-time health monitoring

## License

MIT

## Support

For issues and questions, please visit:

- GitHub: https://github.com/Gracelium64/dartBackendServer
- Documentation: https://shadowapp.dev/docs

## Changelog

### 0.1.0

- Initial release
- Authentication (signup, login, logout, refresh)
- Document CRUD operations
- Media upload/download
- React hooks and context provider
