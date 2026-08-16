import { useCallback, useEffect, useState } from "react";
import { api } from "@/shared/lib/api";
import { localCache, LocalCacheKeys } from "@/shared/lib/localCache";
import { offlineQueue } from "@/shared/lib/offlineQueue";

const PULL_SINCE_KEY = "teriyascore.sync.since";

type SyncPushResult = {
  accepted: string[];
  rejected: Array<{ clientMutationId: string; reason: string }>;
  serverTime: string;
};

type SyncPullResult = {
  operations?: Record<string, unknown>[];
  clients?: Record<string, unknown>[];
  stock?: Record<string, unknown>[];
  serverTime: string;
  nextSince?: string;
  hasMore?: boolean;
};

export function useSync() {
  const [pending, setPending] = useState(offlineQueue.count());
  const [lastError, setLastError] = useState<string | null>(null);

  const refresh = useCallback(() => setPending(offlineQueue.count()), []);

  const pull = useCallback(async () => {
    if (!navigator.onLine) return;
    let since = localStorage.getItem(PULL_SINCE_KEY) ?? new Date(0).toISOString();
    try {
      let pages = 0;
      let hasMore = true;
      while (hasMore && pages < 10) {
        pages += 1;
        const res = await api.get<SyncPullResult>(
          `/sync/pull?since=${encodeURIComponent(since)}&limit=100`
        );
        if (res.operations?.length) {
          localCache.mergeListById(LocalCacheKeys.operations, res.operations);
        }
        if (res.clients?.length) {
          localCache.mergeListById(LocalCacheKeys.clients, res.clients);
        }
        if (res.stock?.length) {
          localCache.mergeListById(LocalCacheKeys.stock, res.stock);
        }
        since = res.nextSince ?? res.serverTime;
        localStorage.setItem(PULL_SINCE_KEY, since);
        hasMore = Boolean(res.hasMore);
      }
      // Warm lecture pour écrans clés (meilleure UX hors ligne).
      await Promise.allSettled([
        api.get<unknown[]>("/operations").then((list) => {
          localCache.setList(
            LocalCacheKeys.operations,
            list as Record<string, unknown>[]
          );
        }),
        api.get<unknown[]>("/clients").then((list) => {
          localCache.setList(
            LocalCacheKeys.clients,
            list as Record<string, unknown>[]
          );
        }),
        api.get<Record<string, unknown>>("/me").then((me) => {
          localCache.setMap(LocalCacheKeys.profile, me);
        }),
        api.get<{ items?: Record<string, unknown>[] }>("/stock/articles").then((res) => {
          localCache.setList(LocalCacheKeys.stock, res.items ?? []);
        }),
      ]);
    } catch {
      /* pull best-effort */
    }
  }, []);

  const flush = useCallback(async () => {
    const mutations = offlineQueue.list(true);
    if (!navigator.onLine) {
      refresh();
      return;
    }
    try {
      if (mutations.length) {
        const res = await api.post<SyncPushResult>("/sync/push", {
          mutations: mutations.map(({ clientMutationId, kind, payload, createdAt }) => ({
            clientMutationId,
            kind,
            payload,
            createdAt,
          })),
        });
        offlineQueue.clearAccepted(res.accepted);
        if (res.rejected.length) {
          for (const r of res.rejected) {
            offlineQueue.markFailed(r.clientMutationId, r.reason);
          }
          setLastError(res.rejected[0]?.reason ?? "Sync partielle");
        } else {
          setLastError(null);
        }
      }
      await pull();
    } catch {
      // keep queue
    } finally {
      refresh();
    }
  }, [pull, refresh]);

  useEffect(() => {
    void flush();
    const onOnline = () => void flush();
    window.addEventListener("online", onOnline);
    return () => window.removeEventListener("online", onOnline);
  }, [flush]);

  return { pending, flush, pull, refresh, lastError };
}
