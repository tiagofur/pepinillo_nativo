import { useEffect, useState } from "react";
import "./index.css";

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

/* Focus modes mirror FocusMode (ios/Features/Focus/FocusModels.swift:13):
   same names, countdown vs count-up direction, same free-tier gating. */
const MODES = [
  { name: "Pomodoro", detail: "25 min de enfoque · descansos de 5 y 15", glyph: "🍅", free: true },
  { name: "Flowtime", detail: "Cuenta ascendente · descanso sugerido", glyph: "🌊", free: false },
  { name: "Bloque", detail: "Un bloque continuo de 60 min", glyph: "📦", free: false },
  { name: "Cronómetro", detail: "Enfoque libre sin objetivo", glyph: "⏱", free: true },
];

function FocusView() {
  return (
    <div className="view">
      <h1>Enfoque</h1>
      <p className="sub">Elige un modo y empieza en un toque.</p>
      <div className="card timer-wrap">
        <div className="ring" style={{ ["--p" as string]: "0%" }}>
          <b>25:00</b>
        </div>
        <p className="timer-phase">Listo · Pomodoro 1/4</p>
        <div className="timer-actions">
          <button className="btn" type="button" disabled>
            Empezar
          </button>
        </div>
      </div>
      <ul className="modelist">
        {MODES.map((m) => (
          <li key={m.name} className="card">
            <span className="mode-glyph" aria-hidden="true">{m.glyph}</span>
            <span className="grow">
              <b>{m.name}</b>
              <span>{m.detail}</span>
            </span>
            {!m.free && <span className="lock">Plus</span>}
          </li>
        ))}
      </ul>
      <div className="empty">
        <strong>El temporizador en vivo llega en el siguiente paso.</strong>
        Modos, fases y duraciones ya están definidos como en el iPad; falta
        conectar el motor (inicio, pausa, descansos automáticos).
      </div>
    </div>
  );
}

function PlanView() {
  return (
    <div className="view">
      <h1>Plan</h1>
      <p className="sub">Tareas, energía y filtros por día.</p>
      <div className="empty">
        <strong>Aquí vivirá tu lista de tareas.</strong>
        Crear, completar y filtrar tareas con niveles de energía, igual que en
        el iPad. Llega en el paso de tareas.
      </div>
    </div>
  );
}

function DashboardView() {
  return (
    <div className="view">
      <h1>Panel</h1>
      <p className="sub">Tu constancia de un vistazo.</p>
      <div className="empty">
        <strong>Aquí vivirá tu resumen.</strong>
        Sesiones de hoy, minutos de enfoque y racha, calculados de tus
        sesiones reales. Llega con el motor de foco.
      </div>
    </div>
  );
}

function MoreView({ theme, setTheme }: { theme: Theme; setTheme: (t: Theme) => void }) {
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

export default function App() {
  const [tab, setTab] = useState<Tab>("focus");
  const layout = useLayout();
  const [theme, setTheme] = useTheme();

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
