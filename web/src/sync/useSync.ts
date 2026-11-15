import { useCallback, useState } from "react";
import { api, ApiError } from "../api/client";
import { loadSessions } from "../focus/useFocus";
import type { Task } from "../tasks/tasks";
import type { Session } from "../auth/useSession";
import {
  adoptSessions,
  adoptTasks,
  getDeviceId,
  sessionToServer,
  taskToServer,
} from "./mappers";

export type SyncPhase = "idle" | "working" | "ok" | "error";

export interface SyncApi {
  phase: SyncPhase;
  error: string | null;
  lastSyncISO: string | null;
  upload: () => Promise<void>;
}

const LAST_SYNC_KEY = "pepinillo:last-sync";

function readLS(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

/** One-shot initial merge (DataMerge parity): upload local, adopt canonical. */
export function useSync(
  tasks: Task[],
  replaceAll: (next: Task[]) => boolean,
  session: Session,
): SyncApi {
  const [phase, setPhase] = useState<SyncPhase>("idle");
  const [error, setError] = useState<string | null>(null);
  const [lastSyncISO, setLastSyncISO] = useState<string | null>(() => readLS(LAST_SYNC_KEY));

  const upload = useCallback(async () => {
    if (!session.user) {
      setPhase("error");
      setError("Entra a tu cuenta primero.");
      return;
    }
    setPhase("working");
    setError(null);
    try {
      const nowISO = new Date().toISOString();
      const sessions = loadSessions();
      const settings = [
        { key: "theme", value: readLS("pepinillo:theme") ?? "system", updatedAt: nowISO },
        { key: "defaultMode", value: readLS("pepinillo:defaultMode") ?? "pomodoro", updatedAt: nowISO },
      ];
      const res = await api.initialUpload(
        {
          deviceId: getDeviceId(),
          tasks: tasks.map((t) => taskToServer(t, nowISO)),
          sessions: sessions.map((s) => sessionToServer(s, nowISO)),
          settings,
        },
        getDeviceId(),
      );
      replaceAll(adoptTasks(res.tasks));
      try {
        localStorage.setItem("pepinillo:sessions.v1", JSON.stringify(adoptSessions(res.sessions)));
        localStorage.setItem(LAST_SYNC_KEY, nowISO);
      } catch {
        /* Adopted in memory; the timestamp just won't persist. */
      }
      setLastSyncISO(nowISO);
      setPhase("ok");
    } catch (e) {
      setPhase("error");
      if (e instanceof ApiError && (e.status === 402 || e.code === "ERR_TIER_INSUFFICIENT")) {
        setError("La sincronización requiere Everywhere.");
      } else if (e instanceof ApiError) {
        setError(e.message);
      } else {
        setError("Sin conexión con el servidor.");
      }
    }
  }, [tasks, replaceAll, session.user]);

  return { phase, error, lastSyncISO, upload };
}
