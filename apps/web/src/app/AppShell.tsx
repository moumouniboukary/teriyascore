import { NavLink, Outlet } from "react-router-dom";
import { useSync } from "@/features/sync/useSync";

const links = [
  {
    to: "/app",
    end: true,
    label: "Dossiers",
    icon: (
      <svg viewBox="0 0 24 24" aria-hidden>
        <path d="M6 4h9l5 5v11a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1Z" />
        <path d="M14 4v6h6" />
      </svg>
    ),
  },
  {
    to: "/app/profil",
    label: "Profil",
    icon: (
      <svg viewBox="0 0 24 24" aria-hidden>
        <circle cx="12" cy="9" r="3.5" />
        <path d="M6.5 19c1.5-3 3.5-4.5 5.5-4.5s4 1.5 5.5 4.5" />
      </svg>
    ),
  },
] as const;

export function AppShell() {
  useSync();

  return (
    <div className="app-shell">
      <div className="app-main">
        <Outlet />
      </div>
      <nav className="bottom-nav" aria-label="Navigation principale">
        {links.map((l) => (
          <NavLink
            key={l.to}
            to={l.to}
            end={"end" in l ? l.end : false}
            className={({ isActive }) => (isActive ? "active" : undefined)}
          >
            {l.icon}
            <span>{l.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
