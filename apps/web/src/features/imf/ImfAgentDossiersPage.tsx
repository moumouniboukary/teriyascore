import { useCallback, useEffect, useState } from "react";
import { PartnerApiError, partnerRequest } from "./partnerApi";

type Driver = { key: string; label: string; delta: number };

type AgentRow = {
  id: string;
  clientNom: string;
  clientTelephone?: string | null;
  score: number;
  recommendation: string;
  chargeRate: number;
  montantSoutenableFcfa: number;
  echeanceEstimeeFcfa: number;
  revenuMensuelFcfa: number;
  montantDemandeFcfa: number;
  drivers: Driver[] | unknown;
  statut: string;
  motifDecision?: string | null;
  note?: string | null;
  agent?: { nomAffiche?: string; telephone?: string };
  createdAt?: string;
};

const RECO_LABEL: Record<string, string> = {
  recommande: "Dossier recommandé",
  analyse_complementaire: "Analyse complémentaire",
  a_reexaminer: "À réexaminer",
};

const STATUTS = ["soumise", "en_examen", "validee", "a_revoir"] as const;

function money(n: number) {
  return `${Math.round(n).toLocaleString("fr-FR")} F`;
}

function driversOf(row: AgentRow): Driver[] {
  const d = row.drivers;
  if (Array.isArray(d)) return d as Driver[];
  return [];
}

export function ImfAgentDossiersPage() {
  const [rows, setRows] = useState<AgentRow[]>([]);
  const [filter, setFilter] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [motif, setMotif] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setError(null);
    try {
      const q = filter ? `?statut=${encodeURIComponent(filter)}` : "";
      const data = await partnerRequest<AgentRow[]>(`/partners/agent-dossiers${q}`);
      setRows(data);
    } catch (err) {
      setError(err instanceof PartnerApiError ? err.message : "Chargement impossible");
    }
  }, [filter]);

  useEffect(() => {
    void load();
  }, [load]);

  async function decide(id: string, statut: (typeof STATUTS)[number]) {
    setBusyId(id);
    setError(null);
    try {
      await partnerRequest(`/partners/agent-dossiers/${id}/decide`, {
        method: "POST",
        body: JSON.stringify({
          statut,
          motifDecision: motif[id]?.trim() || undefined,
        }),
      });
      await load();
    } catch (err) {
      setError(err instanceof PartnerApiError ? err.message : "Décision échouée");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section>
      <header className="imf-page-head">
        <div>
          <h1>TeriyaScore — suivi dossiers</h1>
          <p className="imf-sub">
            Scorecard terrain · aide à la décision (jamais un verdict automatique)
          </p>
        </div>
        <select value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">Tous statuts</option>
          {STATUTS.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </header>

      {error && <p className="imf-error">{error}</p>}

      <div className="imf-list">
        {rows.length === 0 && (
          <p className="imf-empty">Aucun dossier agent synchronisé.</p>
        )}
        {rows.map((r) => (
          <article key={r.id} className="imf-card">
            <div className="imf-card__top">
              <div>
                <strong>{r.clientNom}</strong>
                <span className="imf-muted">
                  {r.clientTelephone ?? "—"} · {r.statut}
                </span>
              </div>
              <div className="imf-score">{r.score}</div>
            </div>
            <p className="imf-reco">
              {RECO_LABEL[r.recommendation] ?? r.recommendation}
            </p>
            <ul className="imf-meta">
              <li>Demande : {money(r.montantDemandeFcfa)}</li>
              <li>Soutenable : {money(r.montantSoutenableFcfa)}</li>
              <li>Charge : {(r.chargeRate * 100).toFixed(0)} %</li>
              <li>Échéance est. : {money(r.echeanceEstimeeFcfa)}</li>
            </ul>
            <div className="imf-drivers">
              <span>3 facteurs :</span>
              {driversOf(r).map((d) => (
                <em key={d.key}>
                  {d.label} (+{d.delta})
                </em>
              ))}
            </div>
            <input
              placeholder="Motif (optionnel)"
              value={motif[r.id] ?? ""}
              onChange={(e) =>
                setMotif((m) => ({ ...m, [r.id]: e.target.value }))
              }
            />
            <div className="imf-actions">
              {(["en_examen", "validee", "a_revoir"] as const).map((s) => (
                <button
                  key={s}
                  type="button"
                  disabled={busyId === r.id}
                  onClick={() => void decide(r.id, s)}
                >
                  {s}
                </button>
              ))}
            </div>
          </article>
        ))}
      </div>

      <style>{`
        .imf-page-head { display:flex; flex-wrap:wrap; gap:12px; justify-content:space-between; align-items:flex-start; margin-bottom:18px; }
        .imf-page-head h1 { margin:0; font-size:1.35rem; }
        .imf-sub { margin:6px 0 0; color:#3d5a4c; font-size:.92rem; }
        .imf-error { color:#a33; background:#fde8e6; padding:10px 12px; border-radius:10px; }
        .imf-empty { color:#567; }
        .imf-list { display:grid; gap:14px; }
        .imf-card { background:#fff; border:1px solid #d5e4dc; border-radius:14px; padding:14px 16px; }
        .imf-card__top { display:flex; justify-content:space-between; gap:12px; align-items:flex-start; }
        .imf-card__top strong { display:block; font-size:1.05rem; }
        .imf-muted { display:block; color:#5a7266; font-size:.85rem; margin-top:2px; }
        .imf-score { font-size:1.8rem; font-weight:800; color:#3d7eff; line-height:1; }
        .imf-reco { margin:10px 0; font-weight:700; color:#0c1224; }
        .imf-meta { list-style:none; padding:0; margin:0 0 10px; display:flex; flex-wrap:wrap; gap:10px 16px; color:#334; font-size:.9rem; }
        .imf-drivers { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin-bottom:12px; font-size:.88rem; }
        .imf-drivers em { font-style:normal; background:#e8eefc; padding:4px 8px; border-radius:999px; }
        .imf-card input { width:100%; box-sizing:border-box; padding:8px 10px; border-radius:8px; border:1px solid #c9d3e8; margin-bottom:10px; }
        .imf-actions { display:flex; flex-wrap:wrap; gap:8px; }
        .imf-actions button { border:0; background:#3d7eff; color:#071018; border-radius:8px; padding:8px 12px; cursor:pointer; font-weight:700; }
        .imf-actions button:disabled { opacity:.5; }
      `}</style>
    </section>
  );
}
