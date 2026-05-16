# Shadow App Backend Server

Version: 0.1.1  
Repository: Gracelium64/dartBackendServer  
Runtime: Dart + Shelf + SQLite

## 1) System Requirements

- Dart SDK: >=3.0.0 <4.0.0
- SQLite runtime via sqlite3 package (local file database)
- Recommended operator environment: Linux/macOS; CLI designed with cross-platform intent (including Windows)
- Default server bind: 0.0.0.0:8080
- Minimum free disk guidance: 100 MB (baseline)

## 2) Working Features

- Authentication: signup, login, JWT refresh, protected routes
- CRUD: users, collections, documents (with owner/role checks)
- Admin SQL endpoint with statement cap (max 5 statements per execution)
- Media endpoints: upload, download, metadata
- Audit logging: request/action logging, recent logs endpoint, SSE stream
- Operator CLI modes: server, log-tail, admin
- Client access paths: Flutter SDK, React SDK, CLI client, direct REST API

## 3) Media Upload and Storage Capabilities

- Storage model:
- Uploaded media is stored in SQLite table media_blobs as compressed bytes in blob_data (BLOB).
- Upload handler compresses incoming payload with gzip before DB insert.

- Maximum upload size in current implementation:
- There is no explicit application-level max upload-size guard in the server upload handler.
- Therefore, the practical max is constrained by runtime memory, request transport limits, and SQLite/BLOB constraints.

- Database maximum (theoretical ceiling):
- SQLite BLOB max is build/runtime dependent and much higher than typical app-safe upload limits.
- Practical operations should treat this as far lower due to current in-memory upload parsing/compression behavior.

- Operational limits currently affecting uploads:
- Server multipart parser is simplified and reads the multipart body as text, then converts via codeUnits.
- This can corrupt binary media and increases memory pressure for large files.
- Upload path performs in-memory handling (parse + gzip) before persistence, which is not stream-safe for large payloads.
- Flutter SDK upload timeout is 2x network timeout (default 30s => 60s for uploads).
- React SDK uses Axios client timeout (default 30s unless overridden by client config).

- Additional current limitations:
- No server-enforced per-file upload cap with 413 response.
- No per-user or global storage quotas.
- No MIME allowlist/denylist enforcement.
- No resumable/chunked upload protocol.
- No malware/content scanning hook.

## 4) Developing / In-Progress Features

- Replace simplified multipart parser with binary-safe streaming multipart parser.
- Add configurable MAX_UPLOAD_BYTES enforcement and explicit HTTP 413 behavior.
- Add media quota controls (per-user and global), plus MIME policy enforcement.
- Add upload observability (size/reject metrics, structured operational logs).
- Tighten admin-console authentication gate consistency.

## 5) Framework and SDK Support

- Backend framework: Shelf + shelf_router + shelf_cors_headers
- Flutter support: first-party Flutter SDK package (auth/CRUD/media/admin SQL helper)
- React support: TypeScript React SDK with hooks/context, React 18/19 peer support
- CLI support: Dart CLI client for remote operations
- Language-agnostic integration: REST API and cURL/JS/Python usage patterns in docs
