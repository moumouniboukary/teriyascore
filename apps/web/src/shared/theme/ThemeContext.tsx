import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api } from "@/shared/lib/api";

export type ThemeMode = "light" | "dark" | "system";
export type ResolvedTheme = "light" | "dark";

const STORAGE_KEY = "ts-theme";

type ThemeContextValue = {
  theme: ThemeMode;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: ThemeMode) => void;
  persistTheme: (theme: ThemeMode) => Promise<void>;
};

const ThemeContext = createContext<ThemeContextValue | null>(null);

function normalizeTheme(value: unknown): ThemeMode {
  if (value === "light" || value === "dark" || value === "system") return value;
  return "light";
}

function systemResolved(): ResolvedTheme {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: light)").matches
    ? "light"
    : "dark";
}

function resolveTheme(theme: ThemeMode): ResolvedTheme {
  return theme === "system" ? systemResolved() : theme;
}

function readStoredTheme(): ThemeMode {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw == null) return "light";
    const normalized = normalizeTheme(raw);
    // Migration ancien défaut « system »
    if (raw === "system" && localStorage.getItem(`${STORAGE_KEY}-v2`) !== "1") {
      localStorage.setItem(`${STORAGE_KEY}-v2`, "1");
      return "light";
    }
    return normalized;
  } catch {
    return "light";
  }
}

function applyDomTheme(theme: ThemeMode) {
  const resolved = resolveTheme(theme);
  document.documentElement.dataset.theme = resolved;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) {
    meta.setAttribute("content", resolved === "light" ? "#E8ECF6" : "#070B16");
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemeMode>(() => {
    const initial = readStoredTheme();
    applyDomTheme(initial);
    return initial;
  });
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>(() =>
    resolveTheme(readStoredTheme())
  );

  useEffect(() => {
    applyDomTheme(theme);
    setResolvedTheme(resolveTheme(theme));
    try {
      localStorage.setItem(STORAGE_KEY, theme);
      localStorage.setItem(`${STORAGE_KEY}-v2`, "1");
    } catch {
      // ignore
    }
  }, [theme]);

  useEffect(() => {
    if (theme !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: light)");
    const onChange = () => {
      applyDomTheme("system");
      setResolvedTheme(systemResolved());
    };
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  const setTheme = useCallback((next: ThemeMode) => {
    setThemeState(normalizeTheme(next));
  }, []);

  const persistTheme = useCallback(async (next: ThemeMode) => {
    const value = normalizeTheme(next);
    setThemeState(value);
    try {
      await api.patch("/me/preferences", { theme: value });
    } catch {
      // PrÃ©fÃ©rence locale conservÃ©e hors ligne
    }
  }, []);

  const value = useMemo(
    () => ({ theme, resolvedTheme, setTheme, persistTheme }),
    [theme, resolvedTheme, setTheme, persistTheme]
  );

  return (
    <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}
