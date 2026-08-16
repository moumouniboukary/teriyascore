import { useAuth } from "@/features/auth/AuthContext";

export function DashboardPage() {
  const { user } = useAuth();
  const firstName = (user?.displayName || "Agent").split(" ")[0];

  return (
    <div className="page">
      <header className="dash-header">
        <div>
          <p className="dash-hello">Bonjour</p>
          <h1 className="dash-name">{firstName}</h1>
        </div>
      </header>

      <section className="card" style={{ marginTop: 8 }}>
        <h2 className="h2" style={{ fontSize: "1.1rem", marginBottom: 8 }}>
          Espace agent DigiCoop
        </h2>
        <p className="muted" style={{ lineHeight: 1.5 }}>
          TeriyaScore sert à constituer un dossier de solvabilité sur le
          terrain : profil, confiance, historique (si client connu) et
          capacité de remboursement. Le score (300–850) se calcule dans
          l’application mobile, même hors ligne. La décision de crédit reste
          du ressort de l’agent et de la coopérative.
        </p>
      </section>

      <p className="muted" style={{ marginTop: 16, fontSize: 13 }}>
        Identité et consentements se gèrent dans le Profil.
      </p>
    </div>
  );
}
