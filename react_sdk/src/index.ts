/**
 * Shadow App Backend React SDK
 *
 * React SDK for easy integration with the Shadow App Dart Backend Server.
 * Provides a type-safe client, React hooks, and context provider.
 *
 * @example
 * ```tsx
 * import { ShadowAppClient, ShadowAppProvider, useAuth, useDocuments } from '@shadow-app/react-sdk';
 *
 * // Create client
 * const client = new ShadowAppClient({ baseURL: 'http://localhost:8080' });
 *
 * // Or use provider
 * <ShadowAppProvider config={{ baseURL: 'http://localhost:8080' }}>
 *   <App />
 * </ShadowAppProvider>
 * ```
 */

// Export client
export { ShadowAppClient } from "./client";

// Export hooks
export {
  useAuth,
  useDocument,
  useDocuments,
  useMediaUpload,
  useMedia,
  useHealthCheck,
} from "./hooks";

// Export context
export { ShadowAppProvider, useShadowApp } from "./context";

// Export types
export type {
  ShadowAppConfig,
  AuthTokens,
  User,
  SignupRequest,
  LoginRequest,
  AuthResponse,
  RefreshTokenResponse,
  Collection,
  Document,
  CreateDocumentRequest,
  UpdateDocumentRequest,
  ListDocumentsParams,
  ListDocumentsResponse,
  MediaMetadata,
  UploadMediaRequest,
  UploadMediaResponse,
  AuditLog,
  LogsResponse,
  AdminSqlResponse,
  AdminSqlStatementResult,
  ApiError,
  ApiResponse,
} from "./types";

export type {
  UseAuthReturn,
  UseDocumentReturn,
  UseDocumentsReturn,
  UseMediaUploadReturn,
  UseMediaReturn,
  UseHealthCheckReturn,
} from "./hooks";
