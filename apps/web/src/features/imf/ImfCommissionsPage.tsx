import { useCallback, useEffect, useState } from "react";
import { PartnerApiError, partnerRequest } from "./partnerApi";

type Commission = {
  id: string;
  montantFcfa: number;
  statut: string;
  demandeCreditId?: string;
  createdAt?: string;
};

export function ImfCommissionsPage() {
  const [rows, setRows] = useState<Commission[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setRows(await partnerRequest<Commission[]>("/partners/commissions"));
    } catch (err) {
      setError(err instanceof PartnerApiError ? err.message : "Erreur commissions");
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function setStatut(id: string, statut: "due" | "facturee" | "payee") {
    setBusyId(id);
    try {
      await partnerRequest(`/partners/commissions/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ statut }),
      });
      await load();
    } catch (err) {
      setError(err instanceof PartnerApiError ? err.message : "Mise Ã  jour Ã©chouÃ©e");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section>
      <h1 style={{ color: "#0c1224" }}>Commissions</h1>
      {error ? <p style={{ color: "#8B1E1E" }}>{error}</p> : null}
      <div style={{ overflow: "auto", background: "#fff", borderRadius: 12, border: "1px solid #d7e4dc" }}>
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: ".92rem" }}>
          <thead>
            <tr style={{ background: "#e8eefc", color: "#0c1224" }}>
              <th style={{ padding: 12, textAlign: "left" }}>ID</th>
              <th style={{ padding: 12, textAlign: "left" }}>Montant</th>
              <th style={{ padding: 12, textAlign: "left" }}>Statut</th>
              <th style={{ padding: 12, textAlign: "left" }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} style={{ borderBottom: "1px solid #e8f0eb" }}>
                <td style={{ padding: 12 }}>{r.id.slice(0, 8)}â€¦</td>
                <td style={{ padding: 12 }}>
                  {r.montantFcfa.toLocaleString("fr-FR")} F
                </td>
                <td style={{ padding: 12 }}>{r.statut}</td>
                <td style={{ padding: 12, display: "flex", gap: 6, flexWrap: "wrap" }}>
                  {(["due", "facturee", "payee"] as const).map((s) => (
                    <button
                      key={s}
                      type="button"
                      disabled={busyId === r.id || r.statut === s}
                      onClick={() => void setStatut(r.id, s)}
                      style={{
                        border: 0,
                        background: "#0c1224",
                        color: "#fff",
                        borderRadius: 6,
                        padding: "5px 8px",
                        fontSize: ".75rem",
                        cursor: "pointer",
                        opacity: busyId === r.id || r.statut === s ? 0.5 : 1,
                      }}
                    >
                      {s}
                    </button>
                  ))}
                </td>
              </tr>
            ))}
            {rows.length === 0 ? (
              <tr>
                <td colSpan={4} style={{ padding: 12 }}>
                  Aucune commission.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </section>
  );
}
