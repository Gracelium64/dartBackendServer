/**
 * React Context for Shadow App Backend SDK
 *
 * Provides a React context provider to share the Shadow App client
 * across your application.
 */

import React, { createContext, useContext, ReactNode } from "react";
import { ShadowAppClient } from "./client";
import type { ShadowAppConfig } from "./types";

interface ShadowAppContextValue {
  client: ShadowAppClient;
}

const ShadowAppContext = createContext<ShadowAppContextValue | null>(null);

export interface ShadowAppProviderProps {
  config: ShadowAppConfig;
  children: ReactNode;
}

/**
 * Provider component to wrap your app with Shadow App client
 *
 * @example
 * ```tsx
 * <ShadowAppProvider config={{ baseURL: 'http://localhost:8080' }}>
 *   <App />
 * </ShadowAppProvider>
 * ```
 */
export function ShadowAppProvider({
  config,
  children,
}: ShadowAppProviderProps) {
  const client = React.useMemo(() => new ShadowAppClient(config), [config]);

  return (
    <ShadowAppContext.Provider value={{ client }}>
      {children}
    </ShadowAppContext.Provider>
  );
}

/**
 * Hook to access the Shadow App client from context
 *
 * @example
 * ```tsx
 * function MyComponent() {
 *   const { client } = useShadowApp();
 *   // Use client...
 * }
 * ```
 */
export function useShadowApp(): ShadowAppContextValue {
  const context = useContext(ShadowAppContext);
  if (!context) {
    throw new Error("useShadowApp must be used within ShadowAppProvider");
  }
  return context;
}
