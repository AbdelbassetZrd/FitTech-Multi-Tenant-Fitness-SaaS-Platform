"use client";

import { useEffect, useRef, ReactNode } from "react";
import { useAuthStore, AuthStoreContext, createAuthStore, type AuthStore } from "@/lib/stores/authStore";

const REFRESH_INTERVAL_MS = 4 * 60 * 1000; // refresh 4 min before the 5-min window

export function AuthProvider({ children }: { children: ReactNode }) {
  const storeRef = useRef<AuthStore | null>(null);
  if (!storeRef.current) {
    storeRef.current = createAuthStore();
  }

  return (
    <AuthStoreContext.Provider value={storeRef.current}>
      <AuthEffects />
      {children}
    </AuthStoreContext.Provider>
  );
}

function AuthEffects() {
  const loadFromStorage = useAuthStore((s) => s.loadFromStorage);
  const refreshAuth = useAuthStore((s) => s.refreshAuth);
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  /* Hydrate on mount */
  useEffect(() => {
    loadFromStorage();
  }, [loadFromStorage]);

  /* Auto-refresh access token while authenticated */
  useEffect(() => {
    if (isAuthenticated) {
      intervalRef.current = setInterval(() => {
        refreshAuth();
      }, REFRESH_INTERVAL_MS);
    }
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isAuthenticated, refreshAuth]);

  return null;
}
