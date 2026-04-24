/**
 * Shadow App Backend API Client
 *
 * Main API client for interacting with the Shadow App Dart Backend Server.
 * Handles authentication, token refresh, and all CRUD operations.
 */

import axios, { AxiosInstance, AxiosError } from "axios";
import type {
  ShadowAppConfig,
  AuthTokens,
  SignupRequest,
  LoginRequest,
  AuthResponse,
  RefreshTokenResponse,
  CreateDocumentRequest,
  UpdateDocumentRequest,
  ListDocumentsParams,
  ListDocumentsResponse,
  Document,
  UploadMediaRequest,
  UploadMediaResponse,
  MediaMetadata,
  LogsResponse,
  Collection,
  User,
  AuditLog,
  AdminSqlResponse,
  ApiError,
} from "./types";

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value === "object" && value !== null) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asNumber(value: unknown): number {
  return typeof value === "number" ? value : 0;
}

function toDocument(raw: unknown): Document {
  const rec = asRecord(raw);
  return {
    id: asString(rec.id),
    collectionId: asString(rec.collectionId ?? rec.collection_id),
    ownerId: asString(rec.ownerId ?? rec.owner_id),
    data: asRecord(rec.data),
    createdAt: asString(rec.createdAt ?? rec.created_at),
    updatedAt: asString(rec.updatedAt ?? rec.updated_at),
  };
}

function toCollection(raw: unknown): Collection {
  const rec = asRecord(raw);
  return {
    id: asString(rec.id),
    name: asString(rec.name),
    ownerId: asString(rec.ownerId ?? rec.owner_id),
    rules: asRecord(rec.rules),
    createdAt: asString(rec.createdAt ?? rec.created_at),
    updatedAt: asString(rec.updatedAt ?? rec.updated_at),
  };
}

function toMediaMetadata(raw: unknown): MediaMetadata {
  const rec = asRecord(raw);
  return {
    id: asString(rec.id),
    documentId: asString(rec.documentId ?? rec.document_id),
    fileName: asString(rec.fileName ?? rec.file_name),
    mimeType: asString(rec.mimeType ?? rec.mime_type),
    originalSize: asNumber(rec.originalSize ?? rec.original_size),
    compressedSize: asNumber(rec.compressedSize ?? rec.compressed_size),
    compressionAlgo: asString(rec.compressionAlgo ?? rec.compression_algo),
    uploadedAt: asString(rec.uploadedAt ?? rec.uploaded_at),
  };
}

function toAuditLog(raw: unknown): AuditLog {
  const rec = asRecord(raw);
  const status = asString(rec.status) === "success" ? "success" : "failed";
  return {
    id: asString(rec.id),
    userId: asString(rec.userId ?? rec.user_id),
    action: asString(rec.action),
    resourceType: asString(rec.resourceType ?? rec.resource_type),
    resourceId: asString(rec.resourceId ?? rec.resource_id),
    status,
    errorMessage: asString(rec.errorMessage ?? rec.error_message) || undefined,
    details: asString(rec.details) || undefined,
    timestamp: asString(rec.timestamp),
  };
}

export class ShadowAppClient {
  private axiosInstance: AxiosInstance;
  private config: ShadowAppConfig;
  private token: string | null = null;
  private refreshPromise: Promise<string> | null = null;

  constructor(config: ShadowAppConfig) {
    this.config = {
      timeout: 30000,
      ...config,
    };

    this.axiosInstance = axios.create({
      baseURL: config.baseURL,
      timeout: this.config.timeout,
      headers: {
        "Content-Type": "application/json",
      },
    });

    // Request interceptor to add auth token
    this.axiosInstance.interceptors.request.use(
      (config) => {
        if (this.token) {
          config.headers.Authorization = `Bearer ${this.token}`;
        }
        return config;
      },
      (error) => Promise.reject(error),
    );

    // Response interceptor to handle token refresh
    this.axiosInstance.interceptors.response.use(
      (response) => response,
      async (error: AxiosError) => {
        const originalRequest = error.config;

        // If 401 and we have a token, try to refresh once and retry request.
        if (
          error.response?.status === 401 &&
          this.token &&
          originalRequest &&
          !(originalRequest as any)._retry &&
          !originalRequest.url?.includes("/auth/refresh")
        ) {
          (originalRequest as any)._retry = true;

          try {
            await this.refreshAccessToken();
            // Retry the original request with new token
            return this.axiosInstance(originalRequest);
          } catch (refreshError) {
            // Refresh failed, clear tokens and notify
            this.clearTokens();
            this.config.onAuthError?.();
            return Promise.reject(refreshError);
          }
        }

        return Promise.reject(this.handleError(error));
      },
    );
  }

  // ==================== Authentication ====================

  /**
   * Sign up a new user
   */
  async signup(request: SignupRequest): Promise<AuthResponse> {
    const response = await this.axiosInstance.post<AuthResponse>(
      "/auth/signup",
      request,
    );

    if (response.data.success) {
      this.setToken(response.data.data.token);
    }

    return response.data;
  }

  /**
   * Log in an existing user
   */
  async login(request: LoginRequest): Promise<AuthResponse> {
    const response = await this.axiosInstance.post<AuthResponse>(
      "/auth/login",
      request,
    );

    if (response.data.success) {
      this.setToken(response.data.data.token);
    }

    return response.data;
  }

  /**
   * Refresh the current JWT token
   */
  async refreshAccessToken(): Promise<string> {
    // Prevent multiple simultaneous refresh requests
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = (async () => {
      try {
        if (!this.token) {
          throw new Error("No token available");
        }

        const response =
          await this.axiosInstance.post<RefreshTokenResponse>("/auth/refresh");

        if (response.data.success) {
          this.setToken(response.data.data.token);
          return response.data.data.token;
        }

        throw new Error("Token refresh failed");
      } finally {
        this.refreshPromise = null;
      }
    })();

    return this.refreshPromise;
  }

  /**
   * Log out (clear tokens)
   */
  logout(): void {
    this.clearTokens();
  }

  /**
   * Set authentication token manually
   */
  setToken(token: string): void {
    this.token = token;
    this.config.onTokenRefresh?.(token);
  }

  /**
   * Backward-compatible alias for setting token manually
   */
  setTokens(tokens: AuthTokens): void {
    this.setToken(tokens.token);
  }

  /**
   * Clear authentication tokens
   */
  clearTokens(): void {
    this.token = null;
  }

  /**
   * Get current access token
   */
  getAccessToken(): string | null {
    return this.token;
  }

  /**
   * Get current token
   */
  getToken(): string | null {
    return this.token;
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return !!this.token;
  }

  // ==================== Documents ====================

  /**
   * Create a new document in a collection
   */
  async createDocument(
    collectionId: string,
    request: CreateDocumentRequest,
  ): Promise<Document> {
    const response = await this.axiosInstance.post<{
      success: boolean;
      data: unknown;
    }>(`/api/collections/${collectionId}/documents`, request.data);
    return toDocument(response.data.data);
  }

  /**
   * Get a document by ID
   */
  async getDocument(
    collectionId: string,
    documentId: string,
  ): Promise<Document> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown;
    }>(`/api/collections/${collectionId}/documents/${documentId}`);
    return toDocument(response.data.data);
  }

  /**
   * Update a document
   */
  async updateDocument(
    collectionId: string,
    documentId: string,
    request: UpdateDocumentRequest,
  ): Promise<Document> {
    const response = await this.axiosInstance.put<{
      success: boolean;
      data: unknown;
    }>(
      `/api/collections/${collectionId}/documents/${documentId}`,
      request.data,
    );
    return toDocument(response.data.data);
  }

  /**
   * Delete a document
   */
  async deleteDocument(
    collectionId: string,
    documentId: string,
  ): Promise<void> {
    await this.axiosInstance.delete(
      `/api/collections/${collectionId}/documents/${documentId}`,
    );
  }

  /**
   * List documents in a collection
   */
  async listDocuments(
    collectionId: string,
    params?: ListDocumentsParams,
  ): Promise<ListDocumentsResponse> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown[];
      pagination: {
        limit: number;
        offset: number;
        count: number;
      };
      timestamp?: string;
    }>(`/api/collections/${collectionId}/documents`, { params });

    return {
      success: response.data.success,
      data: response.data.data.map((item) => toDocument(item)),
      pagination: response.data.pagination,
      timestamp: response.data.timestamp,
    };
  }

  /**
   * List all users (admin only)
   */
  async listUsers(): Promise<User[]> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown[];
    }>("/api/users");

    return response.data.data.map((item) => {
      const user = asRecord(item);
      return {
        id: asString(user.id),
        email: asString(user.email),
        role: asString(user.role) === "admin" ? "admin" : "user",
        createdAt: asString(user.createdAt ?? user.created_at) || undefined,
      };
    });
  }

  /**
   * List all collections visible to the caller
   */
  async listCollections(): Promise<Collection[]> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown[];
    }>("/api/collections");

    return response.data.data.map((item) => toCollection(item));
  }

  /**
   * Create a collection
   */
  async createCollection(
    name: string,
    rules?: Record<string, unknown>,
  ): Promise<Collection> {
    const response = await this.axiosInstance.post<{
      success: boolean;
      data: unknown;
    }>("/api/collections", { name, rules });

    return toCollection(response.data.data);
  }

  /**
   * Delete a collection and all its documents
   */
  async deleteCollection(collectionId: string): Promise<void> {
    await this.axiosInstance.delete(`/api/collections/${collectionId}`);
  }

  /**
   * Execute admin SQL (admin only)
   */
  async executeAdminSql(
    sql: string,
    options?: {
      params?: unknown[];
      maxRows?: number;
      disableRowCap?: boolean;
    },
  ): Promise<AdminSqlResponse> {
    const response = await this.axiosInstance.post<AdminSqlResponse>(
      "/api/admin/sql-query",
      {
        sql,
        params: options?.params ?? [],
        max_rows: options?.maxRows,
        disable_row_cap: options?.disableRowCap ?? false,
      },
    );

    return response.data;
  }

  // ==================== Media ====================

  /**
   * Upload a media file
   */
  async uploadMedia(request: UploadMediaRequest): Promise<UploadMediaResponse> {
    const formData = new FormData();
    formData.append(
      "file",
      request.file,
      request.filename ?? request.file.name,
    );
    formData.append("destination_collection", request.destinationCollection);
    formData.append("destination_doc_id", request.destinationDocId);
    if (request.filename) {
      formData.append("filename", request.filename);
    }

    const response = await this.axiosInstance.post<{
      success: boolean;
      data: {
        id: string;
        original_size: number;
        compressed_size: number;
        compression_algo: string;
      };
      timestamp?: string;
    }>("/api/media/upload", formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });

    return {
      success: response.data.success,
      data: {
        id: response.data.data.id,
        originalSize: response.data.data.original_size,
        compressedSize: response.data.data.compressed_size,
        compressionAlgo: response.data.data.compression_algo,
      },
      timestamp: response.data.timestamp,
    };
  }

  /**
   * Download a media file
   */
  async downloadMedia(mediaId: string): Promise<Blob> {
    const response = await this.axiosInstance.get<Blob>(
      `/api/media/download/${mediaId}`,
      {
        responseType: "blob",
      },
    );
    return response.data;
  }

  /**
   * Get media metadata
   */
  async getMediaMetadata(mediaId: string): Promise<MediaMetadata> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown;
    }>(`/api/media/metadata/${mediaId}`);
    return toMediaMetadata(response.data.data);
  }

  /**
   * Get downloadmedia URL
   */
  getMediaUrl(mediaId: string): string {
    return `${this.config.baseURL}/api/media/download/${mediaId}`;
  }

  // ==================== Logs ====================

  /**
   * Get recent audit logs (admin only)
   */
  async getRecentLogs(limit?: number): Promise<LogsResponse> {
    const response = await this.axiosInstance.get<{
      success: boolean;
      data: unknown[];
      count: number;
    }>("/api/logs/recent", { params: { limit } });

    return {
      success: response.data.success,
      data: response.data.data.map((item) => toAuditLog(item)),
      count: response.data.count,
    };
  }

  // ==================== Health ====================

  /**
   * Check server health
   */
  async healthCheck(): Promise<{ status: string }> {
    const response = await this.axiosInstance.get<{ status: string }>(
      "/health",
    );
    return response.data;
  }

  // ==================== Error Handling ====================

  private handleError(error: AxiosError): ApiError {
    if (error.response) {
      // Server responded with error
      const data = error.response.data as any;
      return {
        error: data?.error || error.message,
        statusCode: error.response.status,
      };
    } else if (error.request) {
      // Request made but no response
      return {
        error: "No response from server",
        statusCode: 0,
      };
    } else {
      // Something else happened
      return {
        error: error.message,
        statusCode: 0,
      };
    }
  }
}
