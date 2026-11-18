import type { SessionRecord } from "../focus/engine";
import type { Task } from "../tasks/tasks";

/* Local export (JSON + CSV) of everything the web keeps in this browser.
   Real functionality, not a placeholder: the files download to disk. */

export interface ExportPayload {
  app: "pepinillo-web";
  version: 1;
  exportedAtISO: string;
  tasks: Task[];
  sessions: SessionRecord[];
}

export function buildExportJSON(tasks: Task[], sessions: SessionRecord[], nowISO: string): string {
  const payload: ExportPayload = { app: "pepinillo-web", version: 1, exportedAtISO: nowISO, tasks, sessions };
  return JSON.stringify(payload, null, 2);
}

function csvCell(value: string | number | boolean | null): string {
  const s = value == null ? "" : String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function buildExportCSV(tasks: Task[], sessions: SessionRecord[]): string {
  const lines = ["kind,id,title_or_mode,detail,done_or_minutes,at"];
  for (const t of tasks) {
    lines.push(
      ["task", t.id, t.title, t.energy, t.done ? "done" : "open", t.createdAtISO].map(csvCell).join(","),
    );
  }
  for (const s of sessions) {
    lines.push(
      ["session", s.id, s.mode, s.completed ? "completed" : "stopped", Math.round(s.durationSec / 60), s.startedAtISO]
        .map(csvCell)
        .join(","),
    );
  }
  return lines.join("\n") + "\n";
}

export function downloadFile(filename: string, content: string, mime: string): void {
  const blob = new Blob([content], { type: `${mime};charset=utf-8` });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
