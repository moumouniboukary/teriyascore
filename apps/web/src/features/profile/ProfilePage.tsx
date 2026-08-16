import { FormEvent, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { api, ApiClientError, isOfflineError } from "@/shared/lib/api";
import { useAuth } from "@/features/auth/AuthContext";
import { localCache, LocalCacheKeys } from "@/shared/lib/localCache";
import { offlineQueue } from "@/shared/lib/offlineQueue";

type ConsentsList = {
  items: Array<{ type: string; accorde: boolean }>;
  policyVersion: string;
};

export function ProfilePage() {
  const { user, logout, refreshMe, setUser } = useAuth();
  const nav = useNavigate();
  const [displayName, setDisplayName] = useState(user?.displayName ?? "");
  const [idType, setIdType] = useState("cni");
  const [idNumber, setIdNumber] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [address, setAddress] = useState("");
  const [kycStatut, setKycStatut] = useState("non_verifie");
  const [shareImf, setShareImf] = useState(false);
  const [consentAnonymized, setConsentAnonymized] = useState(true);
  const [consentMarketing, setConsentMarketing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setDisplayName(user?.displayName ?? "");
  }, [user?.displayName]);



  useEffect(() => {
    api
      .get<{
        displayName?: string;
        kycStatut?: string;
        pieceIdentiteType?: string;
        pieceIdentiteNumero?: string;
        dateNaissance?: string;
        adresse?: string;
      }>("/me")
      .then((me) => {
        localCache.setMap(LocalCacheKeys.profile, me as Record<string, unknown>);
        if (me.displayName) setDisplayName(me.displayName);
        setKycStatut(me.kycStatut ?? "non_verifie");
        setIdType(me.pieceIdentiteType ?? "cni");
        setIdNumber(me.pieceIdentiteNumero ?? "");
        setAddress(me.adresse ?? "");
        if (me.dateNaissance) setBirthDate(me.dateNaissance.slice(0, 10));
      })
      .catch(() => {
        const me = localCache.getMap(LocalCacheKeys.profile);
        if (!me) return;
        if (typeof me.displayName === "string") setDisplayName(me.displayName);
        setKycStatut(String(me.kycStatut ?? "non_verifie"));
        setIdType(String(me.pieceIdentiteType ?? "cni"));
        setIdNumber(String(me.pieceIdentiteNumero ?? ""));
        setAddress(String(me.adresse ?? ""));
        if (typeof me.dateNaissance === "string") {
          setBirthDate(me.dateNaissance.slice(0, 10));
        }
      });

    api
      .get<ConsentsList>("/me/consents")
      .then((res) => {
        const imf = res.items.find((i) => i.type === "partage_imf");
        const anon = res.items.find((i) => i.type === "anonymisation_recherche");
        const marketing = res.items.find(
          (i) => i.type === "marketing_partenaires"
        );
        setShareImf(Boolean(imf?.accorde));
        if (anon) setConsentAnonymized(Boolean(anon.accorde));
        if (marketing) setConsentMarketing(Boolean(marketing.accorde));
      })
      .catch(() => undefined);
  }, []);

  async function saveProfile(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setMessage(null);
    const profilePayload: Record<string, string> = {
      displayName: displayName.trim(),
    };
    if (idNumber.trim()) {
      profilePayload.pieceIdentiteType = idType;
      profilePayload.pieceIdentiteNumero = idNumber.trim();
    }
    if (address.trim()) profilePayload.adresse = address.trim();
    if (birthDate.trim().length >= 10) {
      profilePayload.dateNaissance = birthDate.trim().slice(0, 10);
    }
    const consentsPayload = {
      consentCreditPartners: shareImf,
      consentAnonymized,
      consentMarketing,
    };
    try {
      const me = await api.patch<{
        id: string;
        phone: string;
        displayName: string;
        onboardingCompleted: boolean;
        kycStatut?: string;
      }>("/me", profilePayload);
      setUser({
        id: me.id,
        phone: me.phone,
        displayName: me.displayName,
        onboardingCompleted: me.onboardingCompleted,
      });
      if (me.kycStatut) setKycStatut(me.kycStatut);
      await api.put("/me/consents", consentsPayload);
      await refreshMe().catch(() => undefined);
      setMessage("Profil enregistré");
    } catch (err) {
      const offline =
        !navigator.onLine ||
        isOfflineError(err) ||
        (err instanceof ApiClientError && err.status >= 500);
      if (offline) {
        const createdAt = new Date().toISOString();
        offlineQueue.enqueue({
          clientMutationId: crypto.randomUUID(),
          kind: "update_profile",
          payload: profilePayload,
          createdAt,
        });
        offlineQueue.enqueue({
          clientMutationId: crypto.randomUUID(),
          kind: "update_consents",
          payload: consentsPayload,
          createdAt,
        });
        const existing = localCache.getMap(LocalCacheKeys.profile) ?? {};
        localCache.setMap(LocalCacheKeys.profile, {
          ...existing,
          ...profilePayload,
          kycStatut:
            kycStatut === "non_verifie" ? "en_cours" : kycStatut,
          pendingSync: true,
        });
        if (user) {
          setUser({
            ...user,
            displayName: displayName.trim(),
              });
        }
        setMessage("Enregistré hors ligne — sync au retour réseau");
      } else {
        setError(err instanceof ApiClientError ? err.message : "Échec");
      }
    } finally {
      setSaving(false);
    }
  }

  const kycLabel: Record<string, string> = {
    non_verifie: "Non vérifié",
    en_cours: "En cours",
    verifie: "Vérifié",
    refuse: "Refusé",
  };

  return (
    <div className="page">
      <h1 className="h1">Profil</h1>
      <div className="card" style={{ textAlign: "center" }}>
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: "50%",
            background: "var(--green)",
            color: "var(--on-brand)",
            display: "grid",
            placeItems: "center",
            margin: "0 auto 12px",
            fontWeight: 700,
          }}
        >
          {(user?.displayName || "N").slice(0, 2).toUpperCase()}
        </div>
        <div className="muted">{user?.phone}</div>
        <Link
          to="/app/parametres"
          style={{ display: "inline-block", marginTop: 12, fontWeight: 600 }}
        >
          Paramètres ›
        </Link>
      </div>

      <form onSubmit={saveProfile} className="card">
        <label className="lbl">Nom affiché</label>
        <input
          className="input"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
        />

        <h2 className="h2" style={{ marginTop: 20, fontSize: "1.05rem" }}>
          Identité (KYC)
        </h2>
        <p className="muted" style={{ marginTop: 4 }}>
          Statut : {kycLabel[kycStatut] ?? kycStatut}. Renseignez votre pièce
          d&apos;identité.
        </p>
        <label className="lbl" style={{ display: "block", marginTop: 12 }}>
          Type de pièce
        </label>
        <div className="seg">
          {(
            [
              ["cni", "CNI"],
              ["passport", "Passeport"],
              ["consulaire", "Consulaire"],
              ["autre", "Autre"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={idType === value ? "on" : ""}
              onClick={() => setIdType(value)}
            >
              {label}
            </button>
          ))}
        </div>
        <label className="lbl" style={{ display: "block", marginTop: 12 }}>
          Numéro de pièce
        </label>
        <input
          className="input"
          value={idNumber}
          onChange={(e) => setIdNumber(e.target.value)}
          placeholder="B1234567"
        />
        <label className="lbl" style={{ display: "block", marginTop: 12 }}>
          Date de naissance
        </label>
        <input
          className="input"
          type="date"
          value={birthDate}
          onChange={(e) => setBirthDate(e.target.value)}
        />
        <label className="lbl" style={{ display: "block", marginTop: 12 }}>
          Adresse / quartier
        </label>
        <input
          className="input"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          placeholder="Ouagadougou, secteur…"
        />

        <label className="lbl" style={{ display: "block", marginTop: 16 }}>
          Partage IMF
        </label>
        <div className="seg">
          <button
            type="button"
            className={shareImf ? "on" : ""}
            onClick={() => setShareImf(true)}
          >
            Autoriser
          </button>
          <button
            type="button"
            className={!shareImf ? "on" : ""}
            onClick={() => setShareImf(false)}
          >
            Refuser
          </button>
        </div>
        <label className="lbl" style={{ display: "block", marginTop: 16 }}>
          Anonymisation recherche
        </label>
        <div className="seg">
          <button
            type="button"
            className={consentAnonymized ? "on" : ""}
            onClick={() => setConsentAnonymized(true)}
          >
            Autoriser
          </button>
          <button
            type="button"
            className={!consentAnonymized ? "on" : ""}
            onClick={() => setConsentAnonymized(false)}
          >
            Refuser
          </button>
        </div>
        <label className="lbl" style={{ display: "block", marginTop: 16 }}>
          Offres partenaires
        </label>
        <div className="seg">
          <button
            type="button"
            className={consentMarketing ? "on" : ""}
            onClick={() => setConsentMarketing(true)}
          >
            Autoriser
          </button>
          <button
            type="button"
            className={!consentMarketing ? "on" : ""}
            onClick={() => setConsentMarketing(false)}
          >
            Refuser
          </button>
        </div>
        {message && <p className="muted">{message}</p>}
        {error && <p className="error">{error}</p>}
        <button className="btn btn-primary" disabled={saving}>
          {saving ? "…" : "Enregistrer"}
        </button>
      </form>

      <div className="card">
        <div
          style={{ padding: "10px 0" }}
          className="muted"
        >
          File offline · {offlineQueue.count()}
        </div>
      </div>

      <button
        className="btn btn-outline"
        style={{ color: "var(--coral)", borderColor: "rgba(216,90,48,.5)" }}
        onClick={() => {
          void logout().finally(() => nav("/login"));
        }}
      >
        Se déconnecter
      </button>
    </div>
  );
}
