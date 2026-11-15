import { useMemo, useState } from "react";
import {
  achievements,
  perDaySeries,
  summarizeRange,
  taskBreakdown,
  trendPct,
} from "../focus/stats";
import { buildMonth } from "./calendar";
import type { SessionRecord } from "../focus/engine";
import type { Task } from "../tasks/tasks";

/* Dashboard sections — mirrors DashboardChartsContent, WeeklyReviewView,
   MonthlyReviewView, AchievementsView, CalendarView and TaskAnalyticsView.
   Local journal first; server reports arrive in T12b. Charts are plain
   divs: no chart dependency, full control over the look. */

function isoDaysAgo(n: number, base: Date): string {
  const d = new Date(base);
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

function Trend({ current, previous, unit }: { current: number; previous: number; unit: string }) {
  const pct = trendPct(current, previous);
  if (pct == null) return <span className="badge">sin base previa</span>;
  const up = pct >= 0;
  return (
    <span className="badge" style={up ? { color: "var(--accent)" } : undefined}>
      {up ? "▲" : "▼"} {Math.abs(pct)}% {unit}
    </span>
  );
}

export function ChartsSection({ sessions }: { sessions: SessionRecord[] }) {
  const [days, setDays] = useState<7 | 30 | 365>(7);
  const points = useMemo(() => {
    const daily = perDaySeries(sessions, days, new Date());
    if (days <= 31) return daily.map((p) => ({ label: p.day.slice(5), minutes: p.minutes }));
    const weeks: { label: string; minutes: number }[] = [];
    for (let i = 0; i < daily.length; i += 7) {
      const chunk = daily.slice(i, i + 7);
      weeks.push({
        label: chunk[0].day.slice(5),
        minutes: chunk.reduce((m, p) => m + p.minutes, 0),
      });
    }
    return weeks;
  }, [sessions, days]);
  const max = Math.max(1, ...points.map((p) => p.minutes));
  return (
    <div className="card">
      <strong>Actividad</strong>
      <div className="pills" role="group" aria-label="Periodo">
        {([7, 30, 365] as const).map((d) => (
          <button
            key={d}
            type="button"
            className={days === d ? "pill active" : "pill"}
            onClick={() => setDays(d)}
          >
            {d === 7 ? "7D" : d === 30 ? "30D" : "Año"}
          </button>
        ))}
      </div>
      <div className="bars" role="img" aria-label={`Minutos de enfoque por ${days === 365 ? "semana" : "día"}`}>
        {points.map((p) => (
          <div
            key={p.label}
            className={p.minutes > 0 ? "bar" : "bar dim"}
            style={{ height: `${Math.max(3, Math.round((p.minutes / max) * 100))}%` }}
            title={`${p.label}: ${p.minutes} min`}
          />
        ))}
      </div>
      <p className="sub" style={{ marginBottom: 0 }}>
        {points.reduce((m, p) => m + p.minutes, 0)} min en el periodo.
      </p>
    </div>
  );
}

function ReviewCard({
  title,
  days,
  sessions,
  now,
}: {
  title: string;
  days: 7 | 30;
  sessions: SessionRecord[];
  now: Date;
}) {
  const cur = summarizeRange(sessions, isoDaysAgo(days, now), now.toISOString());
  const prev = summarizeRange(sessions, isoDaysAgo(days * 2, now), isoDaysAgo(days, now));
  return (
    <div className="card">
      <strong>{title}</strong>
      <p className="sub" style={{ marginBottom: 8 }}>
        {cur.sessions} sesiones · {cur.focusMin} min · {cur.activeDays}{" "}
        {cur.activeDays === 1 ? "día activo" : "días activos"}
      </p>
      <span className="badges">
        <Trend current={cur.focusMin} previous={prev.focusMin} unit="minutos" />
        <Trend current={cur.sessions} previous={prev.sessions} unit="sesiones" />
      </span>
    </div>
  );
}

export function ReviewsSection({ sessions }: { sessions: SessionRecord[] }) {
  const now = useMemo(() => new Date(), []);
  return (
    <>
      <ReviewCard title="Últimos 7 días" days={7} sessions={sessions} now={now} />
      <ReviewCard title="Últimos 30 días" days={30} sessions={sessions} now={now} />
    </>
  );
}

export function AchievementsSection({ sessions }: { sessions: SessionRecord[] }) {
  const list = useMemo(() => achievements(sessions, 0, new Date()), [sessions]);
  return (
    <div className="card">
      <strong>Logros</strong>
      <div className="achgrid">
        {list.map((a) => (
          <div key={a.id} className={a.earned ? "card ach" : "card ach locked"}>
            <b>{a.earned ? "★" : "☆"} {a.name}</b>
            <span>{a.detail}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

const DOW = ["L", "M", "X", "J", "V", "S", "D"];
const MONTHS = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];

export function CalendarSection({ sessions, tasks }: { sessions: SessionRecord[]; tasks: Task[] }) {
  const today = useMemo(() => new Date(), []);
  const [cursor, setCursor] = useState({ y: today.getFullYear(), m: today.getMonth() });
  const [selected, setSelected] = useState<string>(() =>
    `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`,
  );
  const weeks = useMemo(
    () => buildMonth(cursor.y, cursor.m, sessions, tasks),
    [cursor, sessions, tasks],
  );
  const shift = (delta: number) => {
    const d = new Date(cursor.y, cursor.m + delta, 1);
    setCursor({ y: d.getFullYear(), m: d.getMonth() });
  };
  const dayTasks = tasks.filter((t) => !t.done && t.dueISO?.slice(0, 10) === selected);
  const daySessions = sessions.filter(
    (s) => new Date(s.startedAtISO).toISOString().slice(0, 10) === selected,
  );
  return (
    <div className="card">
      <div className="detail-head">
        <strong className="grow">
          {MONTHS[cursor.m]} {cursor.y}
        </strong>
        <button type="button" className="iconbtn" aria-label="Mes anterior" onClick={() => shift(-1)}>
          ‹
        </button>
        <button type="button" className="iconbtn" aria-label="Mes siguiente" onClick={() => shift(1)}>
          ›
        </button>
      </div>
      <div className="calgrid">
        {DOW.map((d) => (
          <span key={d} className="caldow">
            {d}
          </span>
        ))}
        {weeks.flat().map((day) => (
          <button
            key={day.key}
            type="button"
            className={
              "calday" +
              (day.inMonth ? "" : " out") +
              (day.key === selected ? " today" : "")
            }
            aria-label={`${day.key}: ${day.minutes} min, ${day.tasksDue} tareas`}
            aria-pressed={day.key === selected}
            onClick={() => setSelected(day.key)}
          >
            {day.dayNumber}
            {day.minutes > 0 && <span className="dot" />}
            {day.tasksDue > 0 && <span className="badge">{day.tasksDue}</span>}
          </button>
        ))}
      </div>
      <p className="sub" style={{ marginBottom: 4, marginTop: 12 }}>
        <strong>{selected}</strong> · {daySessions.length}{" "}
        {daySessions.length === 1 ? "sesión" : "sesiones"} · {dayTasks.length}{" "}
        {dayTasks.length === 1 ? "tarea vence" : "tareas vencen"}
      </p>
      {dayTasks.map((t) => (
        <p key={t.id} className="sub" style={{ margin: "2px 0" }}>
          · {t.title}
        </p>
      ))}
    </div>
  );
}

export function TaskAnalyticsSection({ taskId, title, sessions }: { taskId: string; title: string; sessions: SessionRecord[] }) {
  const mine = sessions.filter((s) => s.taskId === taskId);
  const minutes = Math.round(mine.reduce((m, s) => m + s.durationSec, 0) / 60);
  const completed = mine.filter((s) => s.completed).length;
  const modes = new Set(mine.map((s) => s.mode)).size;
  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>Analítica</h2>
      </div>
      <p className="sub">{title}</p>
      {mine.length === 0 ? (
        <div className="empty">
          <strong>Sin sesiones vinculadas todavía.</strong>
          Vincula sesiones desde el temporizador y vuelve.
        </div>
      ) : (
        <div className="statgrid">
          <div className="card stat">
            <b>{mine.length}</b>
            <span>Sesiones</span>
          </div>
          <div className="card stat">
            <b>{minutes}</b>
            <span>Minutos</span>
          </div>
          <div className="card stat">
            <b>{completed}</b>
            <span>Completadas</span>
          </div>
          <div className="card stat">
            <b>{modes}</b>
            <span>Modos</span>
          </div>
        </div>
      )}
    </div>
  );
}

export function TopTasksSection({ sessions, titles }: { sessions: SessionRecord[]; titles: Map<string, string> }) {
  const rows = taskBreakdown(sessions).slice(0, 5);
  if (rows.length === 0) return null;
  return (
    <div className="card">
      <strong>Tareas con más enfoque</strong>
      <ul className="sublist">
        {rows.map((r) => (
          <li key={r.taskId}>
            <span className="grow">{titles.get(r.taskId) ?? "Tarea eliminada"}</span>
            <span className="badge">
              {r.sessions} ses. · {r.minutes} min
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
