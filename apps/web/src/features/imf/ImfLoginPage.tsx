import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { PartnerApiError } from "./partnerApi";
import { useImfAuth } from "./ImfAuthContext";

export function ImfLoginPage() {
  const { key, login } = useImfAuth();
  const navigate = useNavigate();
  const [apiKey, setApiKey] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (key) return <Navigate to="/imf/dossiers" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(apiKey);
      navigate("/imf/dossiers");
    } catch (err) {
      setError(
        err instanceof PartnerApiError
          ? err.message
          : "Connexion impossible â€” vÃ©rifiez la clÃ© partenaire."
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="imf-login">
      <div className="imf-login__card">
        <p className="imf-login__brand">TeriyaScore Â· Portail IMF</p>
        <h1>Espace partenaire</h1>
        <p className="imf-login__hint">
          Connectez-vous avec la clÃ© API fournie par TeriyaScore
          (<code>X-Partner-Key</code>).
        </p>
        <form onSubmit={onSubmit}>
          <label>
            ClÃ© partenaire
            <input
              type="password"
              autoComplete="off"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              placeholder="ts_partner_â€¦"
              required
            />
          </label>
          {error ? <p className="imf-login__error">{error}</p> : null}
          <button type="submit" disabled={loading || apiKey.trim().length < 8}>
            {loading ? "Connexionâ€¦" : "Entrer"}
          </button>
        </form>
      </div>
      <style>{`
        .imf-login { min-height: 100vh; display:grid; place-items:center;
          background: linear-gradient(160deg, #0c1224 0%, #1a2440 45%, #3d7eff 100%);
          padding: 24px; font-family: "Segoe UI", system-ui, sans-serif; }
        .imf-login__card { width: min(420px, 100%); background:#f7faf8; border-radius:16px;
          padding: 28px 26px; box-shadow: 0 18px 50px rgba(0,0,0,.25); color:#122; }
        .imf-login__brand { margin:0 0 6px; color:#0c1224; font-weight:700; letter-spacing:.02em; }
        .imf-login h1 { margin:0 0 8px; font-size:1.55rem; }
        .imf-login__hint { margin:0 0 18px; color:#456; font-size:.92rem; line-height:1.4; }
        .imf-login label { display:flex; flex-direction:column; gap:6px; font-size:.88rem; font-weight:600; }
        .imf-login input { padding:12px 14px; border:1px solid #c5d5cc; border-radius:10px;
          font-size:1rem; background:#fff; }
        .imf-login button { margin-top:16px; width:100%; padding:12px; border:0; border-radius:10px;
          background:#0c1224; color:#fff; font-weight:700; cursor:pointer; }
        .imf-login button:disabled { opacity:.55; cursor:not-allowed; }
        .imf-login__error { color:#8B1E1E; margin:10px 0 0; font-size:.9rem; }
        code { background:#e6efe9; padding:1px 5px; border-radius:4px; }
      `}</style>
    </div>
  );
}
