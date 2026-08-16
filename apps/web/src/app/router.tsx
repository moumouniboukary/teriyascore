import { BrowserRouter, Navigate, Outlet, Route, Routes } from "react-router-dom";
import { useEffect, type ReactNode } from "react";
import { AuthProvider, useAuth } from "@/features/auth/AuthContext";
import { ThemeProvider, useTheme } from "@/shared/theme/ThemeContext";
import { RequireAuth } from "@/app/guards";
import { AppShell } from "@/app/AppShell";
import { SplashPage } from "@/features/onboarding/SplashPage";
import { LoginPage } from "@/features/auth/LoginPage";
import { ForgotPasswordPage } from "@/features/auth/ForgotPasswordPage";
import { DashboardPage } from "@/features/dashboard/DashboardPage";
import { ProfilePage } from "@/features/profile/ProfilePage";
import { SettingsPage } from "@/features/settings/SettingsPage";
import { AboutHelpPage } from "@/features/settings/AboutHelpPage";
import { ImfAuthProvider } from "@/features/imf/ImfAuthContext";
import { ImfLoginPage } from "@/features/imf/ImfLoginPage";
import { ImfShell } from "@/features/imf/ImfShell";
import { ImfAgentDossiersPage } from "@/features/imf/ImfAgentDossiersPage";
import { ImfReportingPage } from "@/features/imf/ImfReportingPage";
import { ImfCommissionsPage } from "@/features/imf/ImfCommissionsPage";

function ThemeAuthSync({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const { setTheme } = useTheme();
  useEffect(() => {
    // Ne pas réappliquer l'ancien défaut API « system » (battery saver → sombre).
    if (user?.theme === "light" || user?.theme === "dark") {
      setTheme(user.theme);
    }
  }, [user?.theme, setTheme]);
  return children;
}

function ImfRoot() {
  return (
    <ImfAuthProvider>
      <Outlet />
    </ImfAuthProvider>
  );
}

export function AppRouter() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <ThemeAuthSync>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<SplashPage />} />
              <Route path="/login" element={<LoginPage />} />
              <Route path="/forgot-password" element={<ForgotPasswordPage />} />

              <Route element={<RequireAuth />}>
                <Route path="/app" element={<AppShell />}>
                  <Route index element={<DashboardPage />} />
                  <Route path="profil" element={<ProfilePage />} />
                  <Route path="parametres" element={<SettingsPage />} />
                  <Route path="aide" element={<AboutHelpPage />} />
                </Route>
              </Route>

              <Route path="/imf" element={<ImfRoot />}>
                <Route index element={<Navigate to="login" replace />} />
                <Route path="login" element={<ImfLoginPage />} />
                <Route element={<ImfShell />}>
                  <Route path="dossiers" element={<ImfAgentDossiersPage />} />
                  <Route path="reporting" element={<ImfReportingPage />} />
                  <Route path="commissions" element={<ImfCommissionsPage />} />
                </Route>
              </Route>

              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </BrowserRouter>
        </ThemeAuthSync>
      </AuthProvider>
    </ThemeProvider>
  );
}
