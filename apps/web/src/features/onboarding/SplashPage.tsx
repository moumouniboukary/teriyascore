import { Link } from "react-router-dom";
import { useAuth } from "@/features/auth/AuthContext";

export function SplashPage() {
  const { token } = useAuth();
  const dest = token ? "/app" : "/login";

  return (
    <div className="app-shell">
      <div className="auth-screen page no-nav" style={{ justifyContent: "center" }}>
        <header className="auth-hero">
          <p className="brand-mark">TeriyaScore</p>
          <p className="tagline">
            Score de crédit terrain pour les agents DigiCoop — hors ligne, pour les coopératives.
          </p>
        </header>
        <div className="auth-panel">
          <Link to={dest} className="btn btn-primary">
            {token ? "Continuer" : "Commencer"}
          </Link>
          <p className="muted" style={{ textAlign: "center", marginTop: 24, fontSize: 13 }}>
            App mobile · ajoutez TeriyaScore à l’écran d’accueil pour l’utiliser hors navigateur.
          </p>
        </div>
      </div>
    </div>
  );
}
