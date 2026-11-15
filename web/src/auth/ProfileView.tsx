import { useState } from "react";
import { api } from "../api/client";
import { loadSessions } from "../focus/useFocus";
import { TASKS_KEY, parseTasks } from "../tasks/tasks";
import { buildExportCSV, buildExportJSON, downloadFile } from "./export";
import { friendlyError, tierLabel } from "./AuthView";
import type { Session } from "./useSession";

/* Profile — mirrors ProfileView + EditProfileView + ExportView:
   identity, lifetime stats, edit name, email-change flow, local export,
   delete account. No photo upload: the dev backend has noop storage, so
   the avatar is the initial until server storage exists. */

function localLifetime(): { sessions: number; minutes: number; tasksDone: number } {
  try {
    const sessions = loadSessions();
    const tasks = parseTasks(localStorage.getItem(TASKS_KEY));
    return {
      sessions: sessions.length,
      minutes: Math.round(sessions.reduce((m, s) => m + s.durationSec, 0) / 60),
      tasksDone: tasks.filter((t) => t.done).length,
    };
  } catch {
    return { sessions: 0, minutes: 0, tasksDone: 0 };
  }
}

export function ProfileView({ session }: { session: Session }) {
  const user = session.user;
  const [name, setName] = useState(user?.name ?? "");
  const [newEmail, setNewEmail] = useState("");
  const [code, setCode] = useState("");
  const [emailStep, setEmailStep] = useState<"idle" | "code">("idle");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  if (!user) return null;
  const life = localLifetime();

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(friendlyError(e));
    } finally {
      setBusy(false);
    }
  };

  const exportJSON = () => {
    try {
      const tasks = parseTasks(localStorage.getItem(TASKS_KEY));
      downloadFile(
        `pepinillo-${new Date().toISOString().slice(0, 10)}.json`,
        buildExportJSON(tasks, loadSessions(), new Date().toISOString()),
        "application/json",
      );
    } catch {
      setError("No se pudo generar el archivo en este navegador.");
    }
  };

  const exportCSV = () => {
    try {
      const tasks = parseTasks(localStorage.getItem(TASKS_KEY));
      downloadFile(
        `pepinillo-${new Date().toISOString().slice(0, 10)}.csv`,
        buildExportCSV(tasks, loadSessions()),
        "text/csv",
      );
    } catch {
      setError("No se pudo generar el archivo en este navegador.");
    }
  };

  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>Perfil</h2>
      </div>
      {notice && (
        <div className="empty" role="status" style={{ marginTop: 12 }}>
          <strong>{notice}</strong>
        </div>
      )}
      {error && (
        <div className="card" role="alert" style={{ marginTop: 12 }}>
          <strong>{error}</strong>
        </div>
      )}

      <div className="card" style={{ marginTop: 12 }}>
        <div className="account-row">
          <span className="avatar" aria-hidden="true">
            {(user.name.trim()[0] ?? "?").toUpperCase()}
          </span>
          <span className="grow">
            <b>{user.name}</b>
            <span>{user.email}</span>
          </span>
          <span className="badge">{tierLabel(user.subscriptionTier)}</span>
        </div>
        <p className="sub" style={{ marginBottom: 0 }}>
          {user.emailVerified ? "Correo verificado" : "Correo sin verificar"} ·{" "}
          {life.sessions} sesiones · {life.minutes} min · {life.tasksDone} tareas hechas
        </p>
      </div>

      <div className="card">
        <strong>Nombre</strong>
        <div className="composer" style={{ marginTop: 10 }}>
          <input
            className="textinput"
            value={name}
            onChange={(e) => setName(e.target.value)}
            aria-label="Nombre"
            maxLength={100}
          />
          <button
            className="btn btn--ghost"
            type="button"
            disabled={busy || !name.trim() || name.trim() === user.name}
            onClick={() => void run(async () => {
              await api.updateMe({ name: name.trim() });
              await session.reload();
              setNotice("Nombre actualizado.");
            })}
          >
            Guardar
          </button>
        </div>
      </div>

      <div className="card">
        <strong>Cambiar correo</strong>
        {user.pendingEmail && emailStep === "idle" && (
          <p className="sub">Pendiente: {user.pendingEmail}</p>
        )}
        {emailStep === "idle" ? (
          <div className="composer" style={{ marginTop: 10 }}>
            <input
              className="textinput"
              type="email"
              value={newEmail}
              onChange={(e) => setNewEmail(e.target.value)}
              placeholder="nuevo@correo.com"
              aria-label="Nuevo correo"
            />
            <button
              className="btn btn--ghost"
              type="button"
              disabled={busy || !newEmail.trim()}
              onClick={() => void run(async () => {
                await api.requestEmailChange(newEmail.trim());
                setEmailStep("code");
                setNotice("Revisa tu nuevo correo: te enviamos un código.");
              })}
            >
              Enviar código
            </button>
          </div>
        ) : (
          <div>
            <div className="composer" style={{ marginTop: 10 }}>
              <input
                className="textinput"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="Código"
                aria-label="Código de confirmación"
              />
              <button
                className="btn"
                type="button"
                disabled={busy || !code.trim()}
                onClick={() => void run(async () => {
                  await api.confirmEmailChange(code.trim());
                  await session.reload();
                  setEmailStep("idle");
                  setCode("");
                  setNewEmail("");
                  setNotice("Correo actualizado.");
                })}
              >
                Confirmar
              </button>
            </div>
            <p>
              <button
                type="button"
                className="linkbtn"
                disabled={busy}
                onClick={() => void run(async () => {
                  await api.cancelEmailChange();
                  await session.reload();
                  setEmailStep("idle");
                  setNotice("Cambio de correo cancelado.");
                })}
              >
                Cancelar cambio
              </button>
            </p>
          </div>
        )}
      </div>

      <div className="card">
        <strong>Exportar mis datos</strong>
        <p className="sub">Tareas y sesiones de este navegador, descargadas a disco.</p>
        <div className="timer-actions" style={{ justifyContent: "flex-start" }}>
          <button className="btn btn--ghost" type="button" onClick={exportJSON}>
            JSON
          </button>
          <button className="btn btn--ghost" type="button" onClick={exportCSV}>
            CSV
          </button>
        </div>
      </div>

      <div className="card">
        <strong>Zona de peligro</strong>
        {!confirmDelete ? (
          <p style={{ marginBottom: 0 }}>
            <button className="btn btn--ghost" type="button" onClick={() => setConfirmDelete(true)}>
              Eliminar cuenta para siempre
            </button>
          </p>
        ) : (
          <div>
            <p className="sub">Se borran tu cuenta y tus datos del servidor. No hay vuelta atrás.</p>
            <div className="timer-actions" style={{ justifyContent: "flex-start" }}>
              <button
                className="btn"
                type="button"
                disabled={busy}
                onClick={() => void run(async () => {
                  await api.deleteAccount();
                  window.location.reload();
                })}
              >
                Sí, eliminar todo
              </button>
              <button className="btn btn--ghost" type="button" onClick={() => setConfirmDelete(false)}>
                Cancelar
              </button>
            </div>
          </div>
        )}
        <p style={{ marginBottom: 0 }}>
          <button className="btn btn--ghost" type="button" onClick={() => void session.logout()}>
            Salir
          </button>
        </p>
      </div>
    </div>
  );
}
