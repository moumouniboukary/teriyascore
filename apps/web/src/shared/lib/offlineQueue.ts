import type { SyncMutationKind } from "@teriyascore/shared";

const QUEUE_KEY = "teriyascore.offlineQueue";

export type QueuedMutation = {
  clientMutationId: string;
  kind: SyncMutationKind;
  payload: Record<string, unknown>;
  createdAt: string;
  /** pending | failed — les failed ne sont plus rejouées automatiquement. */
  status?: "pending" | "failed";
  failReason?: string;
};

function readQueue(): QueuedMutation[] {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) ?? "[]") as QueuedMutation[];
  } catch {
    return [];
  }
}

function writeQueue(q: QueuedMutation[]) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(q));
}

export const offlineQueue = {
  enqueue(mutation: QueuedMutation) {
    const q = readQueue();
    q.push({ ...mutation, status: mutation.status ?? "pending" });
    writeQueue(q);
  },
  list(pendingOnly = false) {
    const all = readQueue();
    if (pendingOnly) {
      return all.filter((m) => (m.status ?? "pending") === "pending");
    }
    return all;
  },
  clearAccepted(ids: string[]) {
    writeQueue(readQueue().filter((m) => !ids.includes(m.clientMutationId)));
  },
  markFailed(clientMutationId: string, reason: string) {
    writeQueue(
      readQueue().map((m) =>
        m.clientMutationId === clientMutationId
          ? { ...m, status: "failed" as const, failReason: reason }
          : m
      )
    );
  },
  count() {
    return readQueue().filter((m) => (m.status ?? "pending") === "pending").length;
  },
};
