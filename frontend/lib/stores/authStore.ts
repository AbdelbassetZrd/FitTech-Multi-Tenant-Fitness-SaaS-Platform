"use client";

import { createStore } from "zustand/vanilla";
import { useStore } from "zustand";
import { createContext, useContext } from "react";
import {
  loginApi,
  logoutApi,
  refreshTokenApi,
  getProfileApi,
  googleLoginApi,
  type User,
} from "@/lib/api";

/* ── Storage helpers ───────────────────────────────────────────────────── */

const TOKEN_KEY = "fittech_tokens";

function persistTokens(access: string, refresh: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem(TOKEN_KEY, JSON.stringify({ access, refresh }));
  // Set cookie for middleware route protection
  document.cookie = "fittech_authenticated=true; path=/; max-age=604800; SameSite=Lax";
}

function clearTokens() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
  // Clear middleware cookie
  document.cookie = "fittech_authenticated=; path=/; max-age=0";
}

function loadTokens(): { access: string; refresh: string } | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(TOKEN_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

/* ── Store types ───────────────────────────────────────────────────────── */

interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isHydrated: boolean;

  login: (email: string, password: string) => Promise<void>;
  loginWithGoogle: (token: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshAuth: () => Promise<boolean>;
  loadFromStorage: () => Promise<void>;
  setUser: (user: User) => void;
}

/* ── Store ─────────────────────────────────────────────────────────────── */

export type AuthStore = ReturnType<typeof createAuthStore>;

export const createAuthStore = () => createStore<AuthState>()((set, get) => ({
  user: null,
  accessToken: null,
  refreshToken: null,
  isAuthenticated: false,
  isLoading: false,
  isHydrated: false,

  login: async (email, password) => {
    set({ isLoading: true });
    try {
      const res = await loginApi(email, password);
      persistTokens(res.access, res.refresh);
      set({
        user: res.user,
        accessToken: res.access,
        refreshToken: res.refresh,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (err) {
      set({ isLoading: false });
      throw err;
    }
  },

  loginWithGoogle: async (token) => {
    set({ isLoading: true });
    try {
      const res = await googleLoginApi(token);
      persistTokens(res.access, res.refresh);
      set({
        user: res.user,
        accessToken: res.access,
        refreshToken: res.refresh,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (err) {
      set({ isLoading: false });
      throw err;
    }
  },

  logout: async () => {
    const { accessToken, refreshToken } = get();
    try {
      if (accessToken && refreshToken) {
        await logoutApi(refreshToken, accessToken);
      }
    } catch {
      // Silently fail — token may already be invalid
    }
    clearTokens();
    set({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,
    });
  },

  refreshAuth: async () => {
    const { refreshToken } = get();
    if (!refreshToken) return false;
    try {
      const res = await refreshTokenApi(refreshToken);
      persistTokens(res.access, refreshToken);
      set({ accessToken: res.access });
      return true;
    } catch {
      clearTokens();
      set({
        user: null,
        accessToken: null,
        refreshToken: null,
        isAuthenticated: false,
      });
      return false;
    }
  },

  loadFromStorage: async () => {
    const tokens = loadTokens();
    if (!tokens) {
      set({ isHydrated: true });
      return;
    }

    set({
      accessToken: tokens.access,
      refreshToken: tokens.refresh,
      isAuthenticated: true, // Optimistically render as authenticated
    });

    try {
      // Try fetching profile with current access token
      const user = await getProfileApi(tokens.access);
      set({
        user,
        isAuthenticated: true,
        isHydrated: true,
      });
    } catch {
      // Access token expired — try refreshing
      try {
        const refreshRes = await refreshTokenApi(tokens.refresh);
        persistTokens(refreshRes.access, tokens.refresh);
        const user = await getProfileApi(refreshRes.access);
        set({
          user,
          accessToken: refreshRes.access,
          isAuthenticated: true,
          isHydrated: true,
        });
      } catch {
        // Refresh also failed — clear everything
        clearTokens();
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          isAuthenticated: false,
          isHydrated: true,
        });
      }
    }
  },

  setUser: (user) => set({ user }),
}));

export const AuthStoreContext = createContext<AuthStore | null>(null);

export function useAuthStore<T>(selector: (state: AuthState) => T): T {
  const store = useContext(AuthStoreContext);
  if (!store) {
    throw new Error("useAuthStore must be used within AuthStoreProvider");
  }
  return useStore(store, selector);
}
