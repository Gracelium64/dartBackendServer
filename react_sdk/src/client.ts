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
  CreateDocumentRequest,
  UpdateDocumentRequest,
  ListDocumentsParams,
  ListDocumentsResponse,
  Document,
  UploadMediaRequest,
  UploadMediaResponse,
  MediaMetadata,
  LogsResponse,
  ApiError,
} from "./types";

export class ShadowAppClient {
  private axiosInstance: AxiosInstance;
  private config: ShadowAppConfig;
  private tokens: AuthTokens | null = null;
  private refreshPromise: Promise<void> | null = null;

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
        if (this.tokens?.accessToken) {
          config.headers.Authorization = `Bearer ${this.tokens.accessToken}`;
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

        // If 401 and we have a refresh token, try to refresh
        if (
          error.response?.status === 401 &&
          this.tokens?.refreshToken &&
          originalRequest &&
          !(originalRequest as any)._retry
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
      this.setTokens({
        accessToken: response.data.data.accessToken,
        refreshToken: response.data.data.refreshToken,
      });
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
      this.setTokens({
        accessToken: response.data.data.accessToken,
        refreshToken: response.data.data.refreshToken,
      });
    }

    return response.data;
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshAccessToken(): Promise<void> {
    // Prevent multiple simultaneous refresh requests
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = (async () => {
      try {
        if (!this.tokens?.refreshToken) {
          throw new Error("No refresh token available");
        }

        const response = await this.axiosInstance.post<AuthResponse>(
          "/auth/refresh",
          { refreshToken: this.tokens.refreshToken },
        );

        if (response.data.success) {
          this.setTokens({
            accessToken: response.data.data.accessToken,
            refreshToken: response.data.data.refreshToken,
          });
        }
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
   * Set authentication tokens manually
   */
  setTokens(tokens: AuthTokens): void {
    this.tokens = tokens;
    this.config.onTokenRefresh?.(tokens.accessToken);
  }

  /**
   * Clear authentication tokens
   */
  clearTokens(): void {
    this.tokens = null;
  }

  /**
   * Get current access token
   */
  getAccessToken(): string | null {
    return this.tokens?.accessToken || null;
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return !!this.tokens?.accessToken;
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
      data: Document;
    }>(`/api/collections/${collectionId}/documents`, request.data);
    return response.data.data;
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
      data: Document;
    }>(`/api/collections/${collectionId}/documents/${documentId}`);
    return response.data.data;
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
      data: Document;
    }>(
      `/api/collections/${collectionId}/documents/${documentId}`,
      request.data,
    );
    return response.data.data;
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
    const response = await this.axiosInstance.get<ListDocumentsResponse>(
      `/api/collections/${collectionId}/documents`,
      { params },
    );
    return response.data;
  }

  // ==================== Media ====================

  /**
   * Upload a media file
   */
  async uploadMedia(request: UploadMediaRequest): Promise<UploadMediaResponse> {
    const formData = new FormData();
    formData.append("file", request.file);
    if (request.filename) {
      formData.append("filename", request.filename);
    }

    const response = await this.axiosInstance.post<UploadMediaResponse>(
      "/api/media/upload",
      formData,
      {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      },
    );
    return response.data;
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
      data: MediaMetadata;
    }>(`/api/media/metadata/${mediaId}`);
    return response.data.data;
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
    const response = await this.axiosInstance.get<LogsResponse>(
      "/api/logs/recent",
      { params: { limit } },
    );
    return response.data;
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
