const PARTNER_KEY = "teriyascore.partnerKey";
const PARTNER_IMF = "teriyascore.partnerImf";

export type PartnerImfInfo = {
  id: string;
  raisonSociale: string;
  tauxCommission?: number | null;
};

export const partnerStorage = {
  getKey(): string | null {
    return localStorage.getItem(PARTNER_KEY);
  },
  setKey(key: string) {
    localStorage.setItem(PARTNER_KEY, key);
  },
  getImf(): PartnerImfInfo | null {
    const raw = localStorage.getItem(PARTNER_IMF);
    return raw ? (JSON.parse(raw) as PartnerImfInfo) : null;
  },
  setImf(imf: PartnerImfInfo | null) {
    if (!imf) localStorage.removeItem(PARTNER_IMF);
    else localStorage.setItem(PARTNER_IMF, JSON.stringify(imf));
  },
  clear() {
    localStorage.removeItem(PARTNER_KEY);
    localStorage.removeItem(PARTNER_IMF);
  },
};

const BASE =
  (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, "") ||
  "/api";

export class PartnerApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public body?: unknown
  ) {
    super(message);
  }
}

export async function partnerRequest<T>(
  path: string,
  init: RequestInit = {}
): Promise<T> {
  const key = partnerStorage.getKey();
  if (!key) throw new PartnerApiError("Clé partenaire manquante", 401);

  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("X-Partner-Key", key);

  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  const text = await res.text();
  let body: unknown = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!res.ok) {
    const msg =
      typeof body === "object" &&
      body &&
      "message" in body &&
      typeof (body as { message: unknown }).message === "string"
        ? (body as { message: string }).message
        : `Erreur ${res.status}`;
    throw new PartnerApiError(msg, res.status, body);
  }
  return body as T;
}
