import { NavLink, Navigate, Outlet } from "react-router-dom";
import { useImfAuth } from "./ImfAuthContext";

export function ImfShell() {
  const { key, imf, logout } = useImfAuth();
  if (!key) return <Navigate to="/imf/login" replace />;

  return (
    <div className="imf-shell">
      <header className="imf-shell__header">
        <div>
          <strong>TeriyaScore — suivi dossiers</strong>
          <span>{imf?.raisonSociale ?? "Partenaire"}</span>
        </div>
        <nav>
          <NavLink to="/imf/dossiers">Dossiers agent</NavLink>
          <NavLink to="/imf/reporting">Reporting</NavLink>
          <NavLink to="/imf/commissions">Commissions</NavLink>
          <button type="button" onClick={logout}>
            Déconnexion
          </button>
        </nav>
      </header>
      <main className="imf-shell__main">
        <Outlet />
      </main>
      <style>{`
        .imf-shell { min-height:100vh; background:#f3f5fb; color:#0c1224;
          font-family:"Manrope", "Segoe UI", system-ui, sans-serif; }
        .imf-shell__header { display:flex; flex-wrap:wrap; gap:12px; justify-content:space-between;
          align-items:center; padding:14px 20px; background:#0c1224; color:#fff; }
        .imf-shell__header strong { display:block; font-size:1.05rem; font-family:"Outfit", sans-serif; }
        .imf-shell__header span { opacity:.85; font-size:.88rem; }
        .imf-shell__header nav { display:flex; flex-wrap:wrap; gap:10px; align-items:center; }
        .imf-shell__header a { color:#c5d4f5; text-decoration:none; padding:6px 10px; border-radius:8px; }
        .imf-shell__header a.active { background:rgba(61,126,255,.28); color:#fff; font-weight:700; }
        .imf-shell__header button { border:1px solid rgba(255,255,255,.35); background:transparent;
          color:#fff; border-radius:8px; padding:6px 10px; cursor:pointer; }
        .imf-shell__main { padding:20px; max-width:1100px; margin:0 auto; }
      `}</style>
    </div>
  );
}
