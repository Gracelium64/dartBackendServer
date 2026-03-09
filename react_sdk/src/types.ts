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
  data: {
    documents: Document[];
    total: number;
    limit: number;
    offset: number;
  };
}

export interface MediaMetadata {
  id: string;
  uploaderId: string;
  filename: string;
  mimeType: string;
  size: number;
  uploadedAt: string;
}

export interface UploadMediaRequest {
  file: File;
  filename?: string;
}

export interface UploadMediaResponse {
  success: boolean;
  data: {
    mediaId: string;
    metadata: MediaMetadata;
  };
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
  data: {
    logs: AuditLog[];
  };
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
