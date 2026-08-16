import { Link } from "react-router-dom";

const SECTIONS: Array<{ title: string; body: string }> = [
  {
    title: "À quoi sert TeriyaScore ?",
    body: "TeriyaScore aide les agents DigiCoop à constituer un dossier de solvabilité sur le terrain, même hors ligne. Vous collectez les infos client, calculez un score, puis envoyez le dossier au retour du réseau. La décision de crédit reste entièrement du ressort de l’agent et de la coopérative.",
  },
  {
    title: "Dossiers terrain",
    body: "L’accueil identifie l’agent et sa coopérative. Un nouveau dossier : Client → Profil → Confiance → Historique (sauté si primo-demandeur) → Capacité. Le score (300–850) se calcule à la fin ; le dossier reste sur le téléphone jusqu’à synchronisation.",
  },
  {
    title: "Score de solvabilité",
    body: "Le score (300–850) résume la solvabilité, avec une catégorie de risque, une décision graduée, 3 facteurs explicatifs, le taux d’endettement et un montant recommandé indicatif. Plus les données sont complètes, plus il est crédible pour l’agent et la coopérative.",
  },
  {
    title: "Hors ligne",
    body: "Sans réseau, les dossiers partent en file locale. La synchronisation reprend au retour de la connexion.",
  },
  {
    title: "Profil vs Paramètres",
    body: "Le Profil sert à l’identité de l’agent (KYC, consentements). Les préférences d’affichage (thème) sont dans Paramètres.",
  },
];

export function AboutHelpPage() {
  return (
    <div className="page">
      <div style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
        <Link to="/app/parametres" className="muted">
          ← Paramètres
        </Link>
      </div>
      <h1 className="h1">À propos & aide</h1>
      <p className="muted" style={{ marginBottom: 16 }}>
        TeriyaScore — score de crédit terrain pour les coopératives et le
        secteur informel au Burkina Faso.
      </p>
      {SECTIONS.map((s) => (
        <details key={s.title} className="card" style={{ marginBottom: 10 }}>
          <summary style={{ cursor: "pointer", fontWeight: 700 }}>
            {s.title}
          </summary>
          <p className="muted" style={{ marginTop: 10, lineHeight: 1.45 }}>
            {s.body}
          </p>
        </details>
      ))}
      <p className="muted" style={{ fontSize: 12, marginTop: 8 }}>
        Les données restent les vôtres. Export / suppression depuis le Profil.
      </p>
    </div>
  );
}
