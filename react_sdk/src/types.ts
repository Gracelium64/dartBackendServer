/**
 * Core types for Shadow App Backend SDK
 */

export interface ShadowAppConfig {
  baseURL: string;
  apiKey?: string;
  timeout?: number;
  onTokenRefresh?: (token: string) => void;
  onAuthError?: () => void;
}

export interface AuthTokens {
  token: string;
}

export interface User {
  id: string;
  email: string;
  role: "user" | "admin";
  createdAt?: string;
}

export interface SignupRequest {
  email: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  success: boolean;
  data: {
    id: string;
    email: string;
    role: "user" | "admin";
    token: string;
  };
}

export interface RefreshTokenResponse {
  success: boolean;
  data: {
    token: string;
  };
}

export interface Collection {
  id: string;
  name: string;
  ownerId: string;
  rules: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export interface Document {
  id: string;
  collectionId: string;
  ownerId: string;
  data: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export interface CreateDocumentRequest {
  data: Record<string, any>;
}

export interface UpdateDocumentRequest {
  data: Record<string, any>;
}

export interface ListDocumentsParams {
  limit?: number;
  offset?: number;
}

export interface ListDocumentsResponse {
  success: boolean;
  data: Document[];
  pagination: {
    limit: number;
    offset: number;
    count: number;
  };
  timestamp?: string;
}

export interface MediaMetadata {
  id: string;
  documentId: string;
  fileName: string;
  mimeType: string;
  originalSize: number;
  compressedSize: number;
  compressionAlgo: string;
  uploadedAt: string;
}

export interface UploadMediaRequest {
  file: File;
  filename?: string;
  destinationCollection: string;
  destinationDocId: string;
}

export interface UploadMediaResponse {
  success: boolean;
  data: {
    id: string;
    originalSize: number;
    compressedSize: number;
    compressionAlgo: string;
  };
  timestamp?: string;
}

export interface AuditLog {
  id: string;
  userId: string;
  action: string;
  resourceType: string;
  resourceId: string;
  status: "success" | "failed";
  errorMessage?: string;
  details?: string;
  timestamp: string;
}

export interface LogsResponse {
  success: boolean;
  data: AuditLog[];
  count: number;
}

export interface AdminSqlStatementResult {
  statement_index: number;
  statement_type: string;
  rows: Array<Record<string, unknown>>;
  row_count: number;
  row_cap_applied: boolean;
}

export interface AdminSqlResponse {
  success: boolean;
  data: AdminSqlStatementResult[];
  meta: {
    statement_count: number;
    total_rows: number;
    max_rows: number | null;
    disable_row_cap: boolean;
    max_statements: number;
  };
  timestamp: string;
}

export interface ApiError {
  error: string;
  statusCode: number;
}

export type ApiResponse<T> =
  | {
      success: true;
      data: T;
    }
  | {
      success: false;
      error: string;
    };
