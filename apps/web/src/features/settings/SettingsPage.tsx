import { FormEvent, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useTheme, type ThemeMode } from "@/shared/theme/ThemeContext";

export function SettingsPage() {
  const { theme, setTheme, persistTheme } = useTheme();
  const [themeDraft, setThemeDraft] = useState<ThemeMode>(theme);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setThemeDraft(theme);
  }, [theme]);

  async function save(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      await persistTheme(themeDraft);
      setMessage("Paramètres enregistrés");
    } catch {
      setError("Impossible d’enregistrer les paramètres");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="page">
      <div style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
        <Link to="/app/profil" className="muted">
          ← Profil
        </Link>
      </div>
      <h1 className="h1">Paramètres</h1>

      <form onSubmit={save} className="card">
        <h2 className="h2" style={{ fontSize: "1.05rem" }}>
          Apparence
        </h2>
        <label className="lbl" style={{ display: "block", marginTop: 12 }}>
          Thème
        </label>
        <div className="seg">
          {(
            [
              ["light", "Clair"],
              ["dark", "Sombre"],
              ["system", "Téléphone"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={themeDraft === value ? "on" : ""}
              onClick={() => {
                setThemeDraft(value);
                setTheme(value);
              }}
            >
              {label}
            </button>
          ))}
        </div>
        <p className="muted" style={{ marginTop: 8, fontSize: 13 }}>
          Astuce : « Clair » évite le basculement sombre lié à l’économiseur
          d’énergie Android.
        </p>

        {message && (
          <p style={{ color: "var(--ok)", marginTop: 12 }}>{message}</p>
        )}
        {error && (
          <p style={{ color: "var(--danger)", marginTop: 12 }}>{error}</p>
        )}

        <button className="btn" type="submit" disabled={saving} style={{ marginTop: 16 }}>
          {saving ? "…" : "Enregistrer"}
        </button>
      </form>

      <Link to="/app/aide" className="card" style={{ display: "block" }}>
        <strong>À propos & aide</strong>
        <div className="muted" style={{ marginTop: 4 }}>
          Comment fonctionne TeriyaScore
        </div>
      </Link>
    </div>
  );
}
