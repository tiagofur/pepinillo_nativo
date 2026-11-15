import { useEffect, useState } from "react";
import { api } from "../api/client";
import type { FocusConfig } from "../focus/config";
import type { Mode } from "../focus/engine";
import type { Session } from "./useSession";

/* Settings — mirrors SettingsView sections: Pomodoro, Time Block, Flowtime,
   General, Notifications, Privacy. Omitted with reason (see feature doc):
   midpoint chime (needs engine support) and iCloud row (covered by the
   Everywhere sync card in Más). */

function Switch({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className="switch"
      data-on={checked}
      onClick={() => onChange(!checked)}
    >
      <span className="knob" />
    </button>
  );
}

function Stepper({
  label,
  value,
  display,
  min,
  max,
  step,
  onChange,
  sub,
}: {
  label: string;
  value: number;
  display: string;
  min: number;
  max: number;
  step: number;
  onChange: (v: number) => void;
  sub?: string;
}) {
  return (
    <div className="setrow">
      <span className="grow">
        <b>{label}</b>
        {sub && <span>{sub}</span>}
      </span>
      <span className="stepper">
        <button type="button" aria-label={`Menos ${label}`} disabled={value <= min} onClick={() => onChange(value - step)}>
          −
        </button>
        <b>{display}</b>
        <button type="button" aria-label={`Más ${label}`} disabled={value >= max} onClick={() => onChange(value + step)}>
          +
        </button>
      </span>
    </div>
  );
}

function Row({
  title,
  sub,
  control,
}: {
  title: string;
  sub?: string;
  control: React.ReactNode;
}) {
  return (
    <div className="setrow">
      <span className="grow">
        <b>{title}</b>
        {sub && <span>{sub}</span>}
      </span>
      {control}
    </div>
  );
}

const DEFAULT_MODE_KEY = "pepinillo:defaultMode";

function readDefaultMode(): Mode {
  try {
    return localStorage.getItem(DEFAULT_MODE_KEY) === "stopwatch" ? "stopwatch" : "pomodoro";
  } catch {
    return "pomodoro";
  }
}

export function SettingsView({
  config,
  onChange,
  session,
  isPro,
  onOpenPaywall,
}: {
  config: FocusConfig;
  onChange: (patch: Partial<FocusConfig>) => void;
  session: Session;
  isPro: boolean;
  onOpenPaywall: () => void;
}) {
  const [defaultMode, setDefaultMode] = useState<Mode>(readDefaultMode);
  const [perm, setPerm] = useState(() =>
    typeof Notification !== "undefined" ? Notification.permission : "denied",
  );
  const [metrics, setMetrics] = useState<boolean | null>(session.user?.metricsOptIn ?? null);
  const [metricsError, setMetricsError] = useState<string | null>(null);

  useEffect(() => {
    setMetrics(session.user?.metricsOptIn ?? null);
  }, [session.user?.metricsOptIn]);

  // Daily reminder + Sunday recap fire while the tab is open (honest scope:
  // the web has no background scheduler; native apps do this in the OS).
  useEffect(() => {
    if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
    try {
      const now = new Date();
      if (config.dailyReminder) {
        const stamp = `pepinillo:notif-daily`;
        if (localStorage.getItem(stamp) !== now.toDateString() && now.getHours() >= config.dailyReminderHour) {
          new Notification("Hora de enfocarte", { body: "Elige una tarea y empieza en un toque." });
          localStorage.setItem(stamp, now.toDateString());
        }
      }
      if (config.weeklyRecap && now.getDay() === 0 && now.getHours() >= 18) {
        const stamp = `pepinillo:notif-weekly`;
        if (localStorage.getItem(stamp) !== now.toDateString()) {
          new Notification("Tu semana en Pepinillo", { body: "Mira tu panel para la reseña semanal." });
          localStorage.setItem(stamp, now.toDateString());
        }
      }
    } catch {
      /* best effort */
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const pickDefaultMode = (m: Mode, free: boolean) => {
    if (!free && !isPro) {
      onOpenPaywall();
      return;
    }
    try {
      localStorage.setItem(DEFAULT_MODE_KEY, m);
    } catch {
      /* session-only */
    }
    setDefaultMode(m);
  };

  return (
    <>
      <div className="card">
        <strong>Pomodoro</strong>
        <Stepper label="Enfoque" value={config.pomodoroSec / 60} display={`${config.pomodoroSec / 60} min`} min={15} max={60} step={5} onChange={(v) => onChange({ pomodoroSec: v * 60 })} />
        <Stepper label="Descanso corto" value={config.shortBreakSec / 60} display={`${config.shortBreakSec / 60} min`} min={1} max={15} step={1} onChange={(v) => onChange({ shortBreakSec: v * 60 })} />
        <Stepper label="Descanso largo" value={config.longBreakSec / 60} display={`${config.longBreakSec / 60} min`} min={5} max={30} step={5} onChange={(v) => onChange({ longBreakSec: v * 60 })} />
        <Stepper label="Pomodoros por ciclo" value={config.pomodorosPerCycle} display={`×${config.pomodorosPerCycle}`} min={2} max={8} step={1} onChange={(v) => onChange({ pomodorosPerCycle: v })} />
        <Row title="Descansos automáticos" control={<Switch checked={config.autoStartBreaks} onChange={(v) => onChange({ autoStartBreaks: v })} label="Descansos automáticos" />} />
        <Row title="Enfoque automático" control={<Switch checked={config.autoStartWork} onChange={(v) => onChange({ autoStartWork: v })} label="Enfoque automático" />} />
      </div>

      <div className="card">
        <strong>Bloque de tiempo</strong>
        <Stepper label="Duración" value={config.blockSec / 60} display={`${config.blockSec / 60} min`} min={15} max={180} step={15} onChange={(v) => onChange({ blockSec: v * 60 })} />
      </div>

      <div className="card">
        <strong>Flowtime</strong>
        <Stepper label="Enfoque mínimo" value={config.flowMinSec / 60} display={`${config.flowMinSec / 60} min`} min={1} max={15} step={1} onChange={(v) => onChange({ flowMinSec: v * 60 })} sub="Antes de sugerir el descanso" />
      </div>

      <div className="card">
        <strong>General</strong>
        <div className="setrow">
          <span className="grow">
            <b>Modo inicial</b>
            <span>Se aplica al volver a Enfoque</span>
          </span>
        </div>
        <div className="seg" role="group" aria-label="Modo inicial" style={{ marginBottom: 6 }}>
          {(
            [
              { id: "pomodoro", name: "Pomodoro", free: true },
              { id: "stopwatch", name: "Cronómetro", free: true },
              { id: "flowtime", name: "Flowtime", free: false },
              { id: "timeBlock", name: "Bloque", free: false },
            ] as { id: Mode; name: string; free: boolean }[]
          ).map((m) => (
            <button
              key={m.id}
              type="button"
              aria-pressed={defaultMode === m.id}
              onClick={() => pickDefaultMode(m.id, m.free)}
            >
              {m.name}
              {!m.free && !isPro ? " · Plus" : ""}
            </button>
          ))}
        </div>
        <Row title="Efectos de sonido" control={<Switch checked={config.soundEnabled} onChange={(v) => onChange({ soundEnabled: v })} label="Efectos de sonido" />} />
        <Row title="Sonido al completar" control={<Switch checked={config.completionSound} onChange={(v) => onChange({ completionSound: v })} label="Sonido al completar" />} />
        <Row title="Vibración" control={<Switch checked={config.hapticsEnabled} onChange={(v) => onChange({ hapticsEnabled: v })} label="Vibración" />} />
        <Row title="Mantener pantalla encendida" sub="Durante la sesión" control={<Switch checked={config.keepScreenOn} onChange={(v) => onChange({ keepScreenOn: v })} label="Mantener pantalla encendida" />} />
        <Row title="Reflexión post-sesión" sub="Preguntar cómo estuvo al terminar" control={<Switch checked={config.reflectionEnabled} onChange={(v) => onChange({ reflectionEnabled: v })} label="Reflexión post-sesión" />} />
        <Row title="Celebrar récords" control={<Switch checked={config.celebrateRecords} onChange={(v) => onChange({ celebrateRecords: v })} label="Celebrar récords" />} />
      </div>

      <div className="card">
        <strong>Notificaciones</strong>
        <p className="sub">Llegan con la pestaña abierta. En nativo las programa el sistema.</p>
        {perm === "default" && (
          <p>
            <button
              className="btn btn--ghost"
              type="button"
              onClick={() => {
                try {
                  void Notification.requestPermission().then((p) => setPerm(p));
                } catch {
                  setPerm("denied");
                }
              }}
            >
              Permitir notificaciones
            </button>
          </p>
        )}
        {perm === "denied" && <p className="sub">Bloqueadas en este navegador.</p>}
        <Row title="Avisos de sesión" sub="Al cambiar de fase" control={<Switch checked={config.sessionAlerts} onChange={(v) => onChange({ sessionAlerts: v })} label="Avisos de sesión" />} />
        <Row title="Recordatorio diario" control={<Switch checked={config.dailyReminder} onChange={(v) => onChange({ dailyReminder: v })} label="Recordatorio diario" />} />
        {config.dailyReminder && (
          <Stepper label="Hora" value={config.dailyReminderHour} display={`${config.dailyReminderHour}:00`} min={0} max={23} step={1} onChange={(v) => onChange({ dailyReminderHour: v })} />
        )}
        <Row title="Resumen semanal" sub="Domingos 18:00" control={<Switch checked={config.weeklyRecap} onChange={(v) => onChange({ weeklyRecap: v })} label="Resumen semanal" />} />
      </div>

      <div className="card">
        <strong>Privacidad</strong>
        {!session.user ? (
          <div className="empty">
            <strong>Requiere cuenta con sincronización.</strong>
            Entra para decidir sobre métricas.
          </div>
        ) : (
          <>
            <Row
              title="Compartir métricas anónimas"
              sub="Sesiones y modos agregados para mejorar Pepinillo. Nunca el contenido de tus tareas."
              control={
                <Switch
                  checked={metrics ?? false}
                  onChange={(v) => {
                    const prev = metrics;
                    setMetrics(v);
                    setMetricsError(null);
                    void api
                      .updateMe({ metricsOptIn: v })
                      .then(() => session.reload().catch(() => {}))
                      .catch(() => {
                        setMetrics(prev ?? false);
                        setMetricsError("No se pudo guardar. Inténtalo de nuevo.");
                      });
                  }}
                  label="Compartir métricas anónimas"
                />
              }
            />
            {metricsError && (
              <p role="alert">
                <strong>{metricsError}</strong>
              </p>
            )}
          </>
        )}
      </div>
    </>
  );
}
