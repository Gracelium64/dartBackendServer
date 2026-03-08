/**
 * React Hooks for Shadow App Backend SDK
 *
 * Provides React hooks for easy integration with React applications.
 * Includes authentication state management, document operations, and real-time updates.
 */

import { useState, useEffect, useCallback, useRef } from "react";
import type { ShadowAppClient } from "./client";
import type {
  User,
  SignupRequest,
  LoginRequest,
  Document,
  CreateDocumentRequest,
  UpdateDocumentRequest,
  ListDocumentsParams,
  UploadMediaRequest,
  MediaMetadata,
  ApiError,
} from "./types";

// ==================== Auth Hooks ====================

export interface UseAuthReturn {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: ApiError | null;
  signup: (request: SignupRequest) => Promise<void>;
  login: (request: LoginRequest) => Promise<void>;
  logout: () => void;
}

/**
 * Hook for managing authentication state
 */
export function useAuth(client: ShadowAppClient): UseAuthReturn {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const signup = useCallback(
    async (request: SignupRequest) => {
      setIsLoading(true);
      setError(null);
      try {
        const response = await client.signup(request);
        if (response.success) {
          setUser(response.data.user);
        }
      } catch (err) {
        setError(err as ApiError);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [client],
  );

  const login = useCallback(
    async (request: LoginRequest) => {
      setIsLoading(true);
      setError(null);
      try {
        const response = await client.login(request);
        if (response.success) {
          setUser(response.data.user);
        }
      } catch (err) {
        setError(err as ApiError);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [client],
  );

  const logout = useCallback(() => {
    client.logout();
    setUser(null);
    setError(null);
  }, [client]);

  return {
    user,
    isAuthenticated: client.isAuthenticated(),
    isLoading,
    error,
    signup,
    login,
    logout,
  };
}

// ==================== Document Hooks ====================

export interface UseDocumentReturn {
  document: Document | null;
  isLoading: boolean;
  error: ApiError | null;
  refetch: () => Promise<void>;
}

/**
 * Hook for fetching a single document
 */
export function useDocument(
  client: ShadowAppClient,
  collectionId: string,
  documentId: string,
): UseDocumentReturn {
  const [document, setDocument] = useState<Document | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const refetch = useCallback(async () => {
    if (!collectionId || !documentId) return;

    setIsLoading(true);
    setError(null);
    try {
      const doc = await client.getDocument(collectionId, documentId);
      setDocument(doc);
    } catch (err) {
      setError(err as ApiError);
    } finally {
      setIsLoading(false);
    }
  }, [client, collectionId, documentId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return {
    document,
    isLoading,
    error,
    refetch,
  };
}

export interface UseDocumentsReturn {
  documents: Document[];
  total: number;
  isLoading: boolean;
  error: ApiError | null;
  refetch: () => Promise<void>;
  createDocument: (request: CreateDocumentRequest) => Promise<Document>;
  updateDocument: (
    documentId: string,
    request: UpdateDocumentRequest,
  ) => Promise<Document>;
  deleteDocument: (documentId: string) => Promise<void>;
}

/**
 * Hook for fetching and managing documents in a collection
 */
export function useDocuments(
  client: ShadowAppClient,
  collectionId: string,
  params?: ListDocumentsParams,
): UseDocumentsReturn {
  const [documents, setDocuments] = useState<Document[]>([]);
  const [total, setTotal] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const refetch = useCallback(async () => {
    if (!collectionId) return;

    setIsLoading(true);
    setError(null);
    try {
      const response = await client.listDocuments(collectionId, params);
      if (response.success) {
        setDocuments(response.data.documents);
        setTotal(response.data.total);
      }
    } catch (err) {
      setError(err as ApiError);
    } finally {
      setIsLoading(false);
    }
  }, [client, collectionId, params]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  const createDocument = useCallback(
    async (request: CreateDocumentRequest) => {
      const doc = await client.createDocument(collectionId, request);
      await refetch();
      return doc;
    },
    [client, collectionId, refetch],
  );

  const updateDocument = useCallback(
    async (documentId: string, request: UpdateDocumentRequest) => {
      const doc = await client.updateDocument(
        collectionId,
        documentId,
        request,
      );
      await refetch();
      return doc;
    },
    [client, collectionId, refetch],
  );

  const deleteDocument = useCallback(
    async (documentId: string) => {
      await client.deleteDocument(collectionId, documentId);
      await refetch();
    },
    [client, collectionId, refetch],
  );

  return {
    documents,
    total,
    isLoading,
    error,
    refetch,
    createDocument,
    updateDocument,
    deleteDocument,
  };
}

// ==================== Media Hooks ====================

export interface UseMediaUploadReturn {
  uploadMedia: (request: UploadMediaRequest) => Promise<string>;
  isUploading: boolean;
  progress: number;
  error: ApiError | null;
}

/**
 * Hook for uploading media files
 */
export function useMediaUpload(client: ShadowAppClient): UseMediaUploadReturn {
  const [isUploading, setIsUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<ApiError | null>(null);

  const uploadMedia = useCallback(
    async (request: UploadMediaRequest): Promise<string> => {
      setIsUploading(true);
      setProgress(0);
      setError(null);

      try {
        const response = await client.uploadMedia(request);
        setProgress(100);
        return response.data.mediaId;
      } catch (err) {
        setError(err as ApiError);
        throw err;
      } finally {
        setIsUploading(false);
      }
    },
    [client],
  );

  return {
    uploadMedia,
    isUploading,
    progress,
    error,
  };
}

export interface UseMediaReturn {
  metadata: MediaMetadata | null;
  isLoading: boolean;
  error: ApiError | null;
  download: () => Promise<Blob>;
  getUrl: () => string;
}

/**
 * Hook for fetching media metadata and downloading files
 */
export function useMedia(
  client: ShadowAppClient,
  mediaId: string,
): UseMediaReturn {
  const [metadata, setMetadata] = useState<MediaMetadata | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  useEffect(() => {
    if (!mediaId) return;

    const fetchMetadata = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const meta = await client.getMediaMetadata(mediaId);
        setMetadata(meta);
      } catch (err) {
        setError(err as ApiError);
      } finally {
        setIsLoading(false);
      }
    };

    fetchMetadata();
  }, [client, mediaId]);

  const download = useCallback(async () => {
    return await client.downloadMedia(mediaId);
  }, [client, mediaId]);

  const getUrl = useCallback(() => {
    return client.getMediaUrl(mediaId);
  }, [client, mediaId]);

  return {
    metadata,
    isLoading,
    error,
    download,
    getUrl,
  };
}

// ==================== Health Check Hook ====================

export interface UseHealthCheckReturn {
  status: string | null;
  isHealthy: boolean;
  isChecking: boolean;
  error: ApiError | null;
  check: () => Promise<void>;
}

/**
 * Hook for monitoring server health
 */
export function useHealthCheck(
  client: ShadowAppClient,
  intervalMs: number = 30000,
): UseHealthCheckReturn {
  const [status, setStatus] = useState<string | null>(null);
  const [isChecking, setIsChecking] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);
  const intervalRef = useRef<NodeJS.Timeout>();

  const check = useCallback(async () => {
    setIsChecking(true);
    setError(null);
    try {
      const response = await client.healthCheck();
      setStatus(response.status);
    } catch (err) {
      setError(err as ApiError);
      setStatus(null);
    } finally {
      setIsChecking(false);
    }
  }, [client]);

  useEffect(() => {
    check();

    if (intervalMs > 0) {
      intervalRef.current = setInterval(check, intervalMs);
    }

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [check, intervalMs]);

  return {
    status,
    isHealthy: status === "ok",
    isChecking,
    error,
    check,
  };
}
