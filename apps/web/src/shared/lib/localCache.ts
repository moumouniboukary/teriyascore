const PREFIX = "teriyascore.localCache.";

export const LocalCacheKeys = {
  operations: "operations",
  clients: "clients",
  score: "score",
  creditOffer: "creditOffer",
  creditApplications: "creditApplications",
  stock: "stock",
  profile: "profile",
} as const;

export const localCache = {
  has(key: string): boolean {
    return localStorage.getItem(PREFIX + key) != null;
  },
  getList(key: string): Record<string, unknown>[] {
    try {
      const raw = localStorage.getItem(PREFIX + key);
      if (!raw) return [];
      const decoded = JSON.parse(raw) as unknown;
      return Array.isArray(decoded)
        ? (decoded as Record<string, unknown>[])
        : [];
    } catch {
      return [];
    }
  },
  setList(key: string, items: Record<string, unknown>[]) {
    localStorage.setItem(PREFIX + key, JSON.stringify(items));
  },
  mergeListById(key: string, incoming: Record<string, unknown>[]) {
    if (!incoming.length) return;
    const byId = new Map<string, Record<string, unknown>>();
    for (const item of this.getList(key)) {
      const id = item.id?.toString();
      if (id) byId.set(id, item);
    }
    for (const item of incoming) {
      const id = item.id?.toString();
      if (id) byId.set(id, item);
    }
    this.setList(key, [...byId.values()]);
  },
  getMap(key: string): Record<string, unknown> | null {
    try {
      const raw = localStorage.getItem(PREFIX + key);
      if (!raw) return null;
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return null;
    }
  },
  setMap(key: string, value: Record<string, unknown>) {
    localStorage.setItem(PREFIX + key, JSON.stringify(value));
  },
};
