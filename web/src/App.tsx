import { useEffect, useMemo, useState } from "react";
import "./index.css";
import { DEFAULTS, MODES, formatClock, phaseLabel, type Mode } from "./focus/engine";
import { loadSessions, useFocus } from "./focus/useFocus";
import { streakDays, summarizeToday } from "./focus/stats";
import {
  ENERGY_LABEL,
  PRIORITY_LABEL,
  sortForList,
  suggestedEnergyForHour,
  useTasks,
  type Energy,
  type Priority,
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

type Scope = "today" | "all";

function PlanView() {
  const t = useTasks();
  const [title, setTitle] = useState("");
  const [energy, setEnergy] = useState<Energy>(() =>
    suggestedEnergyForHour(new Date().getHours()),
  );
  const [priority, setPriority] = useState<Priority>("none");
  const [scope, setScope] = useState<Scope>("today");
  const [energyFilter, setEnergyFilter] = useState<Energy | "all">("all");
  const nowEnergy = suggestedEnergyForHour(new Date().getHours());

  const visible = sortForList(t.tasks).filter(
    (task) =>
      (scope === "all" || task.today || !task.done) &&
      (energyFilter === "all" || task.energy === energyFilter),
  );

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

      <div className="pills" role="group" aria-label="Filtros">
        {(["today", "all"] as Scope[]).map((s) => (
          <button key={s} type="button" className={scope === s ? "pill active" : "pill"} onClick={() => setScope(s)}>
            {s === "today" ? "Hoy" : "Todas"}
          </button>
        ))}
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

      {visible.length === 0 ? (
        <div className="empty">
          <strong>Nada por aquí.</strong>
          Añade tu primera tarea arriba y empieza en un toque.
        </div>
      ) : (
        <ul className="tasklist">
          {visible.map((task) => (
            <li key={task.id} className={task.done ? "card taskrow done" : "card taskrow"}>
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
                <b className={task.done ? "strike" : undefined}>{task.title}</b>
                <span className="badges">
                  <span className="badge">{ENERGY_LABEL[task.energy]}</span>
                  {task.priority !== "none" && <span className="badge">⚑ {PRIORITY_LABEL[task.priority]}</span>}
                  {task.today && <span className="badge">Hoy</span>}
                </span>
              </span>
              <button type="button" className="iconbtn" aria-label={`Eliminar ${task.title}`} onClick={() => t.remove(task.id)}>
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
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

function MoreView({ theme, setTheme }: { theme: Theme; setTheme: (t: Theme) => void }) {
  const [confirmReset, setConfirmReset] = useState(false);
  return (
    <div className="view">
      <h1>Más</h1>
      <p className="sub">Ajustes, cuenta y apariencia.</p>
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
        {tab === "plan" && <PlanView />}
        {tab === "dashboard" && <DashboardView />}
        {tab === "more" && <MoreView theme={theme} setTheme={setTheme} />}
      </main>
      {layout === "tabbar" && (
        <nav className="tabbar glass" aria-label="Principal">
          <Nav tab={tab} setTab={setTab} vertical={false} />
        </nav>
      )}
    </div>
  );
}
