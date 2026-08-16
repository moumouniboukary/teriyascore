import { useEffect, useState } from "react";
import { PartnerApiError, partnerRequest } from "./partnerApi";

type Stats = {
  imf: { id: string; raisonSociale: string; tauxCommission?: number | null };
  demandes: {
    total: number;
    soumises: number;
    enExamen: number;
    approuvees: number;
    refusees: number;
    decaissees: number;
  };
  commissions: { count: number; totalFcfa: number };
};

export function ImfReportingPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        setStats(await partnerRequest<Stats>("/partners/stats"));
      } catch (err) {
        setError(err instanceof PartnerApiError ? err.message : "Erreur reporting");
      }
    })();
  }, []);

  if (error) return <p className="imf-error">{error}</p>;
  if (!stats) return <p>Chargementâ€¦</p>;

  const d = stats.demandes;
  const cards = [
    ["Total dossiers", d.total],
    ["Soumises", d.soumises],
    ["En examen", d.enExamen],
    ["ApprouvÃ©es", d.approuvees],
    ["RefusÃ©es", d.refusees],
    ["DÃ©caissÃ©es", d.decaissees],
    ["Commissions", stats.commissions.count],
    [
      "Montant commissions",
      `${stats.commissions.totalFcfa.toLocaleString("fr-FR")} F`,
    ],
  ] as const;

  return (
    <section>
      <h1 style={{ color: "#0c1224" }}>Reporting</h1>
      <p style={{ color: "#456" }}>
        {stats.imf.raisonSociale}
        {stats.imf.tauxCommission != null
          ? ` Â· commission ${stats.imf.tauxCommission}%`
          : ""}
      </p>
      <div className="imf-cards">
        {cards.map(([label, value]) => (
          <article key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
          </article>
        ))}
      </div>
      <style>{`
        .imf-cards { display:grid; grid-template-columns:repeat(auto-fill,minmax(160px,1fr)); gap:12px; margin-top:16px; }
        .imf-cards article { background:#fff; border:1px solid #d7e4dc; border-radius:12px; padding:14px; }
        .imf-cards span { display:block; color:#567; font-size:.82rem; margin-bottom:6px; }
        .imf-cards strong { font-size:1.25rem; color:#0c1224; }
        .imf-error { color:#8B1E1E; background:#fdeceb; padding:10px 12px; border-radius:8px; }
      `}</style>
    </section>
  );
}
