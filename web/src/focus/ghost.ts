import type { Run } from "./engine";

/* Ghost resume — mirrors ghostResumeTapped/ghostDiscardTapped.
   The hook snapshots the live run (start/pause/transitions/beforeunload);
   on the next mount an unfinished snapshot becomes a resume offer.
   Snapshots older than 24 h are stale: kept as history when meaningful,
   otherwise forgotten. Storage is injected so the rules are testable. */

export interface ActiveSnapshot {
  run: Run;
  base: number;
  since: number | null;
  paused: boolean;
  savedAt: number;
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export const ACTIVE_RUN_KEY = "pepinillo:active-run.v1";
export const GHOST_MAX_AGE_MS = 24 * 60 * 60 * 1000;

export function parseSnapshot(raw: string | null): ActiveSnapshot | null {
  if (!raw) return null;
  try {
    const p = JSON.parse(raw) as Partial<ActiveSnapshot>;
    const r = p.run as Partial<Run> | undefined;
    if (!r || typeof r.mode !== "string" || typeof r.phase !== "string") return null;
    if (typeof r.elapsedSec !== "number" || typeof p.base !== "number") return null;
    if (typeof p.savedAt !== "number" || typeof p.paused !== "boolean") return null;
    if (p.since != null && typeof p.since !== "number") return null;
    return p as ActiveSnapshot;
  } catch {
    return null;
  }
}

export function saveActiveRun(storage: StorageLike, snap: ActiveSnapshot): void {
  try {
    storage.setItem(ACTIVE_RUN_KEY, JSON.stringify(snap));
  } catch {
    /* Best effort: the timer works without the snapshot. */
  }
}

export function clearActiveRun(storage: StorageLike): void {
  try {
    storage.removeItem(ACTIVE_RUN_KEY);
  } catch {
    /* Best effort. */
  }
}

/** Elapsed seconds the snapshot represents at `nowMs`. */
export function elapsedAt(snap: ActiveSnapshot, nowMs: number): number {
  if (snap.paused || snap.since == null) return Math.max(0, snap.base);
  return Math.max(0, snap.base + (nowMs - snap.since) / 1000);
}

export type GhostLoad =
  | { kind: "none" }
  | { kind: "offer"; snapshot: ActiveSnapshot; elapsedSec: number }
  | { kind: "stale"; snapshot: ActiveSnapshot; elapsedSec: number };

export function loadGhost(storage: StorageLike, nowMs: number): GhostLoad {
  let raw: string | null = null;
  try {
    raw = storage.getItem(ACTIVE_RUN_KEY);
  } catch {
    return { kind: "none" };
  }
  const snap = parseSnapshot(raw);
  if (!snap) return { kind: "none" };
  const elapsedSec = elapsedAt(snap, nowMs);
  if (nowMs - snap.savedAt > GHOST_MAX_AGE_MS) return { kind: "stale", snapshot: snap, elapsedSec };
  return { kind: "offer", snapshot: snap, elapsedSec };
}
