import { useEffect, useMemo, useState } from "react";
import "./index.css";
import { DEFAULTS, MODES, formatClock, phaseLabel, type Mode } from "./focus/engine";
import { loadSessions, useFocus } from "./focus/useFocus";
import { bestDayMinutes, streakDays, suggestBestMode, summarizeToday } from "./focus/stats";
import { useSession, type Session } from "./auth/useSession";
import { AuthView, tierLabel, type AuthMode } from "./auth/AuthView";
import { ProfileView } from "./auth/ProfileView";
import { useSync, type SyncApi } from "./sync/useSync";
import {
  ENERGY_LABEL,
  PRIORITY_LABEL,
  filterTasks,
  suggestedEnergyForHour,
  useTasks,
  type Energy,
  type Priority,
  type Task,
  type TaskScope,
} from "./tasks/tasks";

/* Tabs mirror AppFeature.Tab (ios/App/AppFeature.swift:178): same four
   destinations, same order. Glyphs are hand-drawn SVG strokes standing in
   for the SF Symbols (brain.head.profile, checklist, chart.bar.fill,
   ellipsis.circle) which don't exist on the web. */
type Tab = "focus" | "plan" | "dashboard" | "more";

const TABS: { id: Tab; label: string; path: string }[] = [
  {
    id: "focus",
    label: "Enfoque",
    path: "M12 4a8 8 0 1 0 8 8M12 8v4l3 2M9 2h6",
  },
  {
    id: "plan",
    label: "Plan",
    path: "M5 6l2 2 4-4M5 12l2 2 4-4M5 18l2 2 4-4M13 6h8M13 12h8M13 18h8",
  },
  {
    id: "dashboard",
    label: "Panel",
    path: "M5 20V10M12 20V4M19 20v-7M3 20h18",
  },
  {
    id: "more",
    label: "Más",
    path: "M6 12h.01M12 12h.01M18 12h.01",
  },
];

function Glyph({ path }: { path: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={path} />
    </svg>
  );
}

/* Layout mirrors AppView.adaptableTabView (ios/App/AppView.swift:271):
   width < 768 or portrait tablet -> compact top bar (floating pill);
   iPad landscape width -> sidebar; phone widths -> iPhone bottom tabs. */
type Layout = "sidebar" | "topbar" | "tabbar";

function useLayout(): Layout {
  const compute = (): Layout => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    if (w < 640) return "tabbar";
    if (w < 1024 || h >= w) return "topbar";
    return "sidebar";
  };
  const [layout, setLayout] = useState<Layout>(compute);
  useEffect(() => {
    const onResize = () => setLayout(compute());
    window.addEventListener("resize", onResize);
    window.addEventListener("orientationchange", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      window.removeEventListener("orientationchange", onResize);
    };
  }, []);
  return layout;
}

type Theme = "system" | "light" | "dark";

function useTheme(): [Theme, (t: Theme) => void] {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem("pepinillo:theme") as Theme) || "system",
  );
  useEffect(() => {
    if (theme === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem("pepinillo:theme", theme);
    } catch {
      /* Private mode etc: theme just won't persist; page still works. */
    }
  }, [theme]);
  return [theme, setTheme];
}

const RATINGS = [
  { v: 1, glyph: "😞", label: "Fatal" },
  { v: 2, glyph: "😐", label: "Floja" },
  { v: 3, glyph: "🙂", label: "Bien" },
  { v: 4, glyph: "😄", label: "Muy bien" },
  { v: 5, glyph: "🤩", label: "Increíble" },
];

/* Post-session reflection — mirrors SessionJournalView (rating + notes). */
function JournalCard({
  record,
  onSave,
  onSkip,
}: {
  record: { id: string; mode: string; durationSec: number; completed: boolean };
  onSave: (rating: number | null, note: string) => void;
  onSkip: () => void;
}) {
  const [rating, setRating] = useState<number | null>(null);
  const [note, setNote] = useState("");
  const meta = MODES.find((m) => m.id === record.mode);
  return (
    <div className="card" role="dialog" aria-label="Diario de sesión">
      <strong>¿Cómo estuvo?</strong>
      <p className="sub">
        {formatClock(record.durationSec)} de {meta?.name ?? record.mode} ·{" "}
        {record.completed ? "completada" : "detenida"}
      </p>
      <div className="seg" role="group" aria-label="Valoración">
        {RATINGS.map((r) => (
          <button
            key={r.v}
            type="button"
            aria-pressed={rating === r.v}
            aria-label={`${r.v}: ${r.label}`}
            onClick={() => setRating(r.v)}
            style={{ fontSize: 20 }}
          >
            {r.glyph}
          </button>
        ))}
      </div>
      <div style={{ marginTop: 10 }}>
        <textarea
          className="textinput"
          rows={2}
          style={{ width: "100%" }}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Una nota para tu yo futuro…"
          aria-label="Nota de sesión"
        />
      </div>
      <div className="timer-actions" style={{ justifyContent: "flex-start", marginTop: 10 }}>
        <button className="btn" type="button" onClick={() => onSave(rating, note)}>
          Guardar
        </button>
        <button className="btn btn--ghost" type="button" onClick={onSkip}>
          Omitir
        </button>
      </div>
    </div>
  );
}

/* Record banner — mirrors StreakRecordBanner: only when today is the best. */
function RecordBanner() {
  const journal = loadSessions();
  const best = bestDayMinutes(journal);
  if (!best) return null;
  const todayMin = summarizeToday(journal, new Date()).focusMin;
  if (todayMin <= 0 || todayMin < best.minutes) return null;
  return (
    <div className="empty">
      <strong>¡Ritmo de récord! Llevas {todayMin} min hoy.</strong>
      {todayMin === best.minutes ? " Igualas tu mejor día." : " Nuevo récord personal."}
    </div>
  );
}

/* Mode intelligence — mirrors ModeIntelligenceBanner, data-driven only. */
function ModeTipBanner() {
  const tip = suggestBestMode(loadSessions());
  if (!tip) return null;
  const meta = MODES.find((m) => m.id === tip.mode);
  return (
    <div className="empty">
      <strong>Tu mejor modo: {meta?.name ?? tip.mode}.</strong>
      {" "}Completas el {Math.round(tip.rate * 100)}% de esas sesiones ({tip.sessions} registradas).
    </div>
  );
}

function useOnline(): boolean {
  const [online, setOnline] = useState(
    () => typeof navigator === "undefined" || navigator.onLine,
  );
  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    return () => {
      window.removeEventListener("online", on);
      window.removeEventListener("offline", off);
    };
  }, []);
  return online;
}

function FocusView() {
  const f = useFocus();
  const [mode, setMode] = useState<Mode>(() => {
    try {
      return localStorage.getItem("pepinillo:defaultMode") === "stopwatch" ? "stopwatch" : "pomodoro";
    } catch {
      return "pomodoro";
    }
  });
  const meta = MODES.find((m) => m.id === mode) ?? MODES[0];
  const run = f.run;
  const isBreak =
    run?.phase === "shortBreak" || run?.phase === "longBreak" || run?.phase === "flowBreak";

  const shown = run
    ? run.targetSec != null
      ? Math.max(0, run.targetSec - run.elapsedSec)
      : run.elapsedSec
    : meta.id === "pomodoro"
      ? DEFAULTS.pomodoroSec
      : meta.id === "timeBlock"
        ? DEFAULTS.blockSec
        : 0;
  const progress =
    run?.targetSec != null ? Math.min(1, run.elapsedSec / run.targetSec) : 0;

  return (
    <div className="view">
      <h1>Enfoque</h1>
      <p className="sub">Elige un modo y empieza en un toque.</p>

      {f.saveError && (
        <div className="card" role="alert">
          <strong>No se pudo guardar tu sesión en este navegador.</strong>
          <p className="sub">Tu temporizador sigue funcionando; nada se perdió.</p>
          <button className="btn btn--ghost" type="button" onClick={f.retrySave}>
            Reintentar
          </button>
        </div>
      )}
      {f.flash && (
        <div className="card" role="status">
          <strong>{f.flash}</strong>
          <p className="sub">
            <button
              type="button"
              className="btn btn--ghost"
              onClick={f.dismissFlash}
              style={{ padding: "6px 14px", fontSize: 14 }}
            >
              Vale
            </button>
          </p>
        </div>
      )}
      {f.pendingJournal && (
        <JournalCard
          record={f.pendingJournal}
          onSave={(rating, note) => f.completeJournal(rating, note)}
          onSkip={f.skipJournal}
        />
      )}
      {!run && !f.pending && <RecordBanner />}
      {!run && !f.pending && <ModeTipBanner />}

      {meta.free ? (
        <div className="card timer-wrap">
          <div className="ring" style={{ ["--p" as string]: `${progress * 100}%` }}>
            <b>{formatClock(shown)}</b>
          </div>
          <p className="timer-phase">
            {f.paused ? "En pausa" : phaseLabel(run, f.pending?.pomo ?? 1)}
          </p>
          <div className="timer-actions">
            {!run && !f.pending && (
              <button className="btn" type="button" onClick={() => f.start(meta.id)}>
                Empezar
              </button>
            )}
            {!run && f.pending && (
              <button className="btn" type="button" onClick={f.startPending}>
                Empezar enfoque {f.pending.pomo}/{f.pending.pomoTotal}
              </button>
            )}
            {run && !f.paused && (
              <button className="btn btn--ghost" type="button" onClick={f.pause}>
                Pausar
              </button>
            )}
            {run && f.paused && (
              <button className="btn" type="button" onClick={f.resume}>
                Seguir
              </button>
            )}
            {run && isBreak && !f.paused && (
              <button className="btn btn--ghost" type="button" onClick={f.skipBreak}>
                Saltar descanso
              </button>
            )}
            {run && (
              <button className="btn btn--ghost" type="button" onClick={f.stop}>
                Terminar
              </button>
            )}
          </div>
          {f.suggestBreak && (
            <div className="empty" style={{ marginTop: 18 }}>
              <strong>Llevas un buen ritmo. ¿Tomamos un descanso?</strong>
              <p className="sub">
                <button className="btn" type="button" onClick={f.takeFlowBreak}>
                  Descansar
                </button>
              </p>
            </div>
          )}
        </div>
      ) : (
        <div className="card timer-wrap">
          <p className="timer-phase">
            <span className="lock">Plus</span>
          </p>
          <p>
            <strong>{meta.name} es parte de Pepinillo Plus,</strong> igual que
            en el iPad. La cuenta y el pago llegan más adelante.
          </p>
          <div className="timer-actions">
            <button className="btn" type="button" onClick={() => setMode("pomodoro")}>
              Usar Pomodoro
            </button>
          </div>
        </div>
      )}

      <ul className="modelist">
        {MODES.map((m) => (
          <li key={m.id} className="card" style={m.id === mode ? { outline: "2px solid var(--accent)" } : undefined}>
            <span className="mode-glyph" aria-hidden="true">{m.glyph}</span>
            <span className="grow">
              <b>{m.name}</b>
              <span>{m.detail}</span>
            </span>
            {!m.free && <span className="lock">Plus</span>}
            {m.id !== mode && (
              <button className="btn btn--ghost" type="button" onClick={() => { f.stop(); setMode(m.id); }}>
                Elegir
              </button>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

const SCOPES: { id: TaskScope; label: string }[] = [
  { id: "today", label: "Hoy" },
  { id: "inbox", label: "Bandeja" },
  { id: "upcoming", label: "Próximas" },
  { id: "done", label: "Hechas" },
];

type TasksApi = ReturnType<typeof useTasks>;

/* Task detail — mirrors TaskDetailView sections: title+toggle, scheduling,
   energy+priority, recurrence, notes, subtasks, delete with confirm. */
function TaskDetail({
  task,
  t,
  onClose,
  onDeleted,
}: {
  task: Task;
  t: TasksApi;
  onClose: () => void;
  onDeleted: () => void;
}) {
  const [subTitle, setSubTitle] = useState("");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const doneSubs = task.subtasks.filter((s) => s.done).length;
  const addSub = () => {
    if (!subTitle.trim()) return;
    t.addSub(task.id, subTitle);
    setSubTitle("");
  };
  return (
    <div className="card plandetail">
      <div className="detail-head">
        <button
          type="button"
          className="check"
          role="checkbox"
          aria-checked={task.done}
          aria-label={task.done ? "Reabrir" : "Completar"}
          onClick={() => t.toggle(task.id)}
        >
          {task.done ? "✓" : ""}
        </button>
        <input
          className="textinput"
          style={{ flex: 1, minWidth: 0 }}
          value={task.title}
          onChange={(e) => t.update(task.id, { title: e.target.value })}
          aria-label="Título"
        />
        <button type="button" className="iconbtn" aria-label="Cerrar detalle" onClick={onClose}>
          ×
        </button>
      </div>

      <span className="detail-label">Fecha</span>
      <div className="composer-row" style={{ marginTop: 0 }}>
        <input
          type="date"
          className="textinput"
          style={{ flex: "none" }}
          value={task.dueISO?.slice(0, 10) ?? ""}
          onChange={(e) =>
            t.update(task.id, {
              dueISO: e.target.value ? new Date(`${e.target.value}T12:00:00`).toISOString() : null,
            })
          }
          aria-label="Fecha límite"
        />
        <label className="sub" style={{ margin: 0 }}>
          <input
            type="checkbox"
            checked={task.today}
            onChange={(e) => t.update(task.id, { today: e.target.checked })}
          />{" "}
          Hoy
        </label>
      </div>

      <span className="detail-label">Energía y prioridad</span>
      <div className="composer-row" style={{ marginTop: 0 }}>
        <div className="seg" role="group" aria-label="Energía">
          {(["deep", "shallow", "admin"] as Energy[]).map((e) => (
            <button key={e} type="button" aria-pressed={task.energy === e} onClick={() => t.update(task.id, { energy: e })}>
              {ENERGY_LABEL[e]}
            </button>
          ))}
        </div>
        <select value={task.priority} onChange={(e) => t.update(task.id, { priority: e.target.value as Priority })} aria-label="Prioridad">
          {(["none", "low", "medium", "high"] as Priority[]).map((p) => (
            <option key={p} value={p}>{PRIORITY_LABEL[p]}</option>
          ))}
        </select>
      </div>

      <span className="detail-label">Repetición</span>
      <select value={task.recurrence ?? ""} onChange={(e) => t.update(task.id, { recurrence: e.target.value || null })} aria-label="Repetición">
        <option value="">Nunca</option>
        <option value="daily">Diaria</option>
        <option value="weekly">Semanal</option>
      </select>
      <p className="sub">La repetición automática llega con la sincronización.</p>

      <span className="detail-label">Notas</span>
      <textarea
        className="textinput"
        rows={3}
        style={{ width: "100%" }}
        value={task.notes}
        onChange={(e) => t.update(task.id, { notes: e.target.value })}
        placeholder="Detalles…"
        aria-label="Notas"
      />

      <span className="detail-label">
        Subtareas{task.subtasks.length > 0 && ` · ${doneSubs}/${task.subtasks.length}`}
      </span>
      <div className="composer">
        <input
          className="textinput"
          value={subTitle}
          onChange={(e) => setSubTitle(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && addSub()}
          placeholder="Nueva subtarea…"
          aria-label="Nueva subtarea"
        />
        <button className="btn btn--ghost" type="button" onClick={addSub} disabled={!subTitle.trim()}>
          Añadir
        </button>
      </div>
      {task.subtasks.length > 0 && (
        <ul className="sublist">
          {task.subtasks.map((s) => (
            <li key={s.id}>
              <button
                type="button"
                className="check"
                role="checkbox"
                aria-checked={s.done}
                aria-label={s.title}
                onClick={() => t.toggleSub(task.id, s.id)}
                style={{ width: 22, height: 22, fontSize: 12 }}
              >
                {s.done ? "✓" : ""}
              </button>
              <span className={s.done ? "grow strike" : "grow"}>{s.title}</span>
              <button type="button" className="iconbtn" aria-label={`Quitar ${s.title}`} onClick={() => t.removeSub(task.id, s.id)} style={{ fontSize: 18 }}>
                ×
              </button>
            </li>
          ))}
        </ul>
      )}

      <span className="detail-label">Sesiones</span>
      <p className="sub">Vincula sesiones desde el temporizador — llega en el próximo paso.</p>

      {!confirmDelete ? (
        <button className="btn btn--ghost" type="button" onClick={() => setConfirmDelete(true)}>
          Eliminar tarea
        </button>
      ) : (
        <div className="timer-actions" style={{ justifyContent: "flex-start" }}>
          <button className="btn" type="button" onClick={() => { t.remove(task.id); onDeleted(); }}>
            Sí, eliminar
          </button>
          <button className="btn btn--ghost" type="button" onClick={() => setConfirmDelete(false)}>
            Cancelar
          </button>
        </div>
      )}
    </div>
  );
}

function PlanView({ t }: { t: TasksApi }) {
  const [title, setTitle] = useState("");
  const [energy, setEnergy] = useState<Energy>(() =>
    suggestedEnergyForHour(new Date().getHours()),
  );
  const [priority, setPriority] = useState<Priority>("none");
  const [scope, setScope] = useState<TaskScope>("today");
  const [energyFilter, setEnergyFilter] = useState<Energy | "all">("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const nowEnergy = suggestedEnergyForHour(new Date().getHours());

  const visible = filterTasks(t.tasks, scope, energyFilter);
  const selected = t.tasks.find((x) => x.id === selectedId) ?? null;

  const submit = () => {
    if (!title.trim()) return;
    t.add({ title, energy, priority, today: scope === "today" });
    setTitle("");
  };

  return (
    <div className="view">
      <h1>Plan</h1>
      <p className="sub">Tareas, energía y filtros por día.</p>

      {t.storeError && (
        <div className="card" role="alert">
          <strong>No se pudieron guardar tus tareas en este navegador.</strong>
          <p className="sub">La lista en pantalla sigue funcionando.</p>
          <button className="btn btn--ghost" type="button" onClick={t.retry}>
            Reintentar
          </button>
        </div>
      )}

      <div className="card">
        <div className="composer">
          <input
            className="textinput"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && submit()}
            placeholder="Nueva tarea…"
            aria-label="Título de la tarea"
          />
          <button className="btn" type="button" onClick={submit} disabled={!title.trim()}>
            Añadir
          </button>
        </div>
        <div className="composer-row">
          <div className="seg" role="group" aria-label="Energía">
            {(["deep", "shallow", "admin"] as Energy[]).map((e) => (
              <button key={e} type="button" aria-pressed={energy === e} onClick={() => setEnergy(e)}>
                {ENERGY_LABEL[e]}
              </button>
            ))}
          </div>
          <label className="sub" style={{ margin: 0 }}>
            Prioridad{" "}
            <select value={priority} onChange={(e) => setPriority(e.target.value as Priority)}>
              {(["none", "low", "medium", "high"] as Priority[]).map((p) => (
                <option key={p} value={p}>{PRIORITY_LABEL[p]}</option>
              ))}
            </select>
          </label>
        </div>
      </div>

      <div className="pills" role="group" aria-label="Listas">
        {SCOPES.map((s) => (
          <button key={s.id} type="button" className={scope === s.id ? "pill active" : "pill"} onClick={() => setScope(s.id)}>
            {s.label}
          </button>
        ))}
      </div>
      <div className="pills" role="group" aria-label="Filtros">
        {(["all", "deep", "shallow", "admin"] as const).map((e) => (
          <button key={e} type="button" className={energyFilter === e ? "pill active" : "pill"} onClick={() => setEnergyFilter(e)}>
            {e === "all" ? "Toda energía" : ENERGY_LABEL[e]}
          </button>
        ))}
      </div>

      <div className="empty">
        <strong>Tu energía ahora: {ENERGY_LABEL[nowEnergy].toLowerCase()}.</strong>
        {nowEnergy === "deep"
          ? " Buen momento para lo difícil."
          : " Guarda lo profundo para tu próxima ventana de energía alta."}
      </div>

      <div className={selected ? "planwrap split" : "planwrap"}>
        <div>
          {visible.length === 0 ? (
            <div className="empty">
              <strong>Nada por aquí.</strong>
              Añade tu primera tarea arriba y empieza en un toque.
            </div>
          ) : (
            <ul className="tasklist">
              {visible.map((task) => (
                <li
                  key={task.id}
                  className={task.done ? "card taskrow done" : "card taskrow"}
                  style={selected?.id === task.id ? { outline: "2px solid var(--accent)" } : undefined}
                >
                  <button
                    type="button"
                    className="check"
                    role="checkbox"
                    aria-checked={task.done}
                    aria-label={task.done ? `Reabrir ${task.title}` : `Completar ${task.title}`}
                    onClick={() => t.toggle(task.id)}
                  >
                    {task.done ? "✓" : ""}
                  </button>
                  <span className="grow">
                    <button type="button" className="rowtitle" onClick={() => setSelectedId(task.id)}>
                      <b className={task.done ? "strike" : undefined}>{task.title}</b>
                    </button>
                    <span className="badges">
                      <span className="badge">{ENERGY_LABEL[task.energy]}</span>
                      {task.priority !== "none" && <span className="badge">⚑ {PRIORITY_LABEL[task.priority]}</span>}
                      {task.today && <span className="badge">Hoy</span>}
                      {task.dueISO && <span className="badge">{task.dueISO.slice(0, 10)}</span>}
                      {task.subtasks.length > 0 && (
                        <span className="badge">
                          {task.subtasks.filter((s) => s.done).length}/{task.subtasks.length}
                        </span>
                      )}
                    </span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
        {selected && (
          <TaskDetail
            task={selected}
            t={t}
            onClose={() => setSelectedId(null)}
            onDeleted={() => setSelectedId(null)}
          />
        )}
      </div>
    </div>
  );
}

function DashboardView() {
  const summary = useMemo(() => {
    const sessions = loadSessions();
    const now = new Date();
    return { ...summarizeToday(sessions, now), streak: streakDays(sessions, now) };
  }, []);
  const cards = [
    { v: String(summary.sessions), l: "Sesiones hoy" },
    { v: String(summary.focusMin), l: "Minutos de enfoque" },
    { v: String(summary.streak), l: summary.streak === 1 ? "Día de racha" : "Días de racha" },
    { v: String(summary.completed), l: "Completadas" },
  ];
  return (
    <div className="view">
      <h1>Panel</h1>
      <p className="sub">Tu constancia de un vistazo.</p>
      <div className="statgrid">
        {cards.map((c) => (
          <div key={c.l} className="card stat">
            <b>{c.v}</b>
            <span>{c.l}</span>
          </div>
        ))}
      </div>
      {summary.sessions === 0 && (
        <div className="empty">
          <strong>Todavía no hay sesiones hoy.</strong>
          Completa un Pomodoro en Enfoque y vuelve: este resumen se calcula
          de tus sesiones reales.
        </div>
      )}
    </div>
  );
}

function resetAll() {
  try {
    Object.keys(localStorage)
      .filter((k) => k.startsWith("pepinillo:"))
      .forEach((k) => localStorage.removeItem(k));
  } catch {
    /* Private mode: nothing was persisted anyway. */
  }
  window.location.reload();
}

function MoreView({
  theme,
  setTheme,
  session,
  onOpenAuth,
  onOpenProfile,
  sync,
}: {
  theme: Theme;
  setTheme: (t: Theme) => void;
  session: Session;
  onOpenAuth: (mode: AuthMode) => void;
  onOpenProfile: () => void;
  sync: SyncApi;
}) {
  const [confirmReset, setConfirmReset] = useState(false);
  return (
    <div className="view">
      <h1>Más</h1>
      <p className="sub">Ajustes, cuenta y apariencia.</p>
      <div className="card">
        {session.status === "checking" ? (
          <div className="account-row">
            <span className="grow">
              <b>Cuenta Pepinillo</b>
              <span>Comprobando sesión…</span>
            </span>
          </div>
        ) : !session.configured ? (
          <div className="account-row">
            <span className="avatar" aria-hidden="true">P</span>
            <span className="grow">
              <b>Cuenta Pepinillo</b>
              <span>Servidor no configurado: modo local. Define VITE_API_BASE_URL y recarga.</span>
            </span>
          </div>
        ) : !session.user ? (
          <div className="account-row">
            <span className="avatar" aria-hidden="true">?</span>
            <span className="grow">
              <b>Cuenta Pepinillo</b>
              <span>Sincroniza tus datos y desbloquea Plus</span>
            </span>
            <button className="btn" type="button" onClick={() => onOpenAuth("login")}>
              Entrar
            </button>
          </div>
        ) : (
          <div>
            <div className="account-row">
              <span className="avatar" aria-hidden="true">
                {(session.user.name.trim()[0] ?? "?").toUpperCase()}
              </span>
              <span className="grow">
                <b>{session.user.name}</b>
                <span>{session.user.email} · {tierLabel(session.user.subscriptionTier)}</span>
              </span>
              <button className="btn btn--ghost" type="button" onClick={onOpenProfile}>
                Perfil
              </button>
              <button className="btn btn--ghost" type="button" onClick={() => void session.logout()}>
                Salir
              </button>
            </div>
            {!session.user.emailVerified && (
              <p style={{ marginBottom: 0 }}>
                <button type="button" className="linkbtn" onClick={() => onOpenAuth("verify")}>
                  Verifica tu correo para sincronizar →
                </button>
              </p>
            )}
            <div style={{ marginTop: 12 }}>
              <p className="sub" style={{ margin: "0 0 8px" }}>
                {sync.phase === "working"
                  ? "Sincronizando…"
                  : sync.lastSyncISO
                    ? `Última sync: ${new Date(sync.lastSyncISO).toLocaleString()}`
                    : "Sin sincronizar todavía."}
              </p>
              {sync.phase === "error" && sync.error && (
                <div className="card" role="alert">
                  <strong>{sync.error}</strong>
                </div>
              )}
              {sync.phase === "ok" && <p className="sub">Al día con el servidor.</p>}
              <button
                className="btn btn--ghost"
                type="button"
                disabled={sync.phase === "working"}
                onClick={() => void sync.upload()}
              >
                {sync.phase === "working" ? "Sincronizando…" : "Sincronizar ahora"}
              </button>
            </div>
          </div>
        )}
      </div>
      <div className="card">
        <strong>Apariencia</strong>
        <p className="sub">Igual que en el iPad: clara, oscura o el sistema.</p>
        <div className="seg" role="group" aria-label="Apariencia">
          {(["system", "light", "dark"] as Theme[]).map((t) => (
            <button
              key={t}
              type="button"
              aria-pressed={theme === t}
              onClick={() => setTheme(t)}
            >
              {t === "system" ? "Sistema" : t === "light" ? "Clara" : "Oscura"}
            </button>
          ))}
        </div>
      </div>
      <div className="empty">
        <strong>Cuenta y sincronización.</strong>
        La versión web empieza local en este navegador; la cuenta Pepinillo
        Everywhere llegará después, sin cambiar estas pantallas.
      </div>
      <div className="card">
        <strong>Tus datos</strong>
        <p className="sub">Sesiones y tareas viven solo en este navegador.</p>
        {!confirmReset ? (
          <button className="btn btn--ghost" type="button" onClick={() => setConfirmReset(true)}>
            Borrar datos locales
          </button>
        ) : (
          <div className="timer-actions" style={{ justifyContent: "flex-start" }}>
            <button className="btn" type="button" onClick={resetAll}>
              Sí, borrar todo
            </button>
            <button className="btn btn--ghost" type="button" onClick={() => setConfirmReset(false)}>
              Cancelar
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function Nav({ tab, setTab, vertical }: { tab: Tab; setTab: (t: Tab) => void; vertical: boolean }) {
  return (
    <>
      {vertical && (
        <div className="brand" aria-hidden="true">
          <span className="brand-dot">P</span> Pepinillo
        </div>
      )}
      {TABS.map((t) => (
        <button
          key={t.id}
          type="button"
          className={tab === t.id ? "navitem active" : "navitem"}
          aria-current={tab === t.id ? "page" : undefined}
          onClick={() => setTab(t.id)}
        >
          <Glyph path={t.path} />
          {t.label}
        </button>
      ))}
    </>
  );
}

function OnboardingView({ onDone }: { onDone: (mode: Mode) => void }) {
  const [mode, setMode] = useState<Mode>("pomodoro");
  return (
    <div className="onboarding">
      <div className="card glass onboard-card">
        <div className="brand">
          <span className="brand-dot">P</span> Pepinillo
        </div>
        <h1>Empieza a enfocarte en un toque</h1>
        <p className="sub">Elige tu modo para empezar. Podrás cambiarlo cuando quieras.</p>
        <div className="seg" role="group" aria-label="Modo inicial">
          <button type="button" aria-pressed={mode === "pomodoro"} onClick={() => setMode("pomodoro")}>
            🍅 Pomodoro
          </button>
          <button type="button" aria-pressed={mode === "stopwatch"} onClick={() => setMode("stopwatch")}>
            ⏱ Cronómetro
          </button>
        </div>
        <p>
          <button className="btn" type="button" onClick={() => onDone(mode)}>
            Empezar
          </button>
        </p>
      </div>
    </div>
  );
}

export default function App() {
  const [tab, setTab] = useState<Tab>("focus");
  const layout = useLayout();
  const [theme, setTheme] = useTheme();
  const session = useSession();
  const tasksApi = useTasks();
  const sync = useSync(tasksApi.tasks, tasksApi.replaceAll, session);
  const online = useOnline();
  const [sheet, setSheet] = useState<
    null | { kind: "auth"; mode: AuthMode; email: string } | { kind: "profile" }
  >(null);
  const openAuth = (mode: AuthMode) => {
    setSheet({ kind: "auth", mode, email: session.user?.email ?? "" });
  };
  const [onboarded, setOnboarded] = useState(() => {
    try {
      return localStorage.getItem("pepinillo:onboarded") === "1";
    } catch {
      return true;
    }
  });

  if (!onboarded) {
    return (
      <div className="shell shell--topbar">
        <OnboardingView
          onDone={(mode) => {
            try {
              localStorage.setItem("pepinillo:onboarded", "1");
              localStorage.setItem("pepinillo:defaultMode", mode);
            } catch {
              /* Session-only: still let the user in. */
            }
            setOnboarded(true);
          }}
        />
      </div>
    );
  }

  return (
    <div className={`shell shell--${layout}`}>
      {!online && (
        <div className="offlinebar glass" role="alert">
          Sin conexión — tus datos siguen en este navegador.
        </div>
      )}
      {layout === "sidebar" && (
        <nav className="sidebar glass" aria-label="Principal">
          <Nav tab={tab} setTab={setTab} vertical />
        </nav>
      )}
      {layout === "topbar" && (
        <nav className="topbar glass" aria-label="Principal">
          <Nav tab={tab} setTab={setTab} vertical={false} />
        </nav>
      )}
      <main className="content">
        {tab === "focus" && <FocusView />}
        {tab === "plan" && <PlanView t={tasksApi} />}
        {tab === "dashboard" && <DashboardView />}
        {tab === "more" && (
          <MoreView
            theme={theme}
            setTheme={setTheme}
            session={session}
            onOpenAuth={openAuth}
            onOpenProfile={() => setSheet({ kind: "profile" })}
            sync={sync}
          />
        )}
      </main>
      {layout === "tabbar" && (
        <nav className="tabbar glass" aria-label="Principal">
          <Nav tab={tab} setTab={setTab} vertical={false} />
        </nav>
      )}
      {sheet && (
        <div className="sheet-backdrop" onClick={() => setSheet(null)}>
          <div
            className="sheet glass"
            role="dialog"
            aria-modal="true"
            aria-label="Cuenta"
            onClick={(e) => e.stopPropagation()}
          >
            <p style={{ textAlign: "right", margin: "0 0 4px" }}>
              <button type="button" className="linkbtn" onClick={() => setSheet(null)}>
                Cerrar
              </button>
            </p>
            {sheet.kind === "auth" ? (
              <AuthView
                session={session}
                initialMode={sheet.mode}
                initialEmail={sheet.email}
                onAuthed={() => setSheet(null)}
                onGuest={() => setSheet(null)}
              />
            ) : (
              <ProfileView session={session} />
            )}
          </div>
        </div>
      )}
    </div>
  );
}
