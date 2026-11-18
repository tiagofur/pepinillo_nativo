import { useState } from "react";
import { api, ApiError, type SubscriptionTier } from "../api/client";
import type { Session } from "./useSession";

export type AuthMode = "login" | "register" | "forgot" | "reset" | "verify";

export function tierLabel(tier: SubscriptionTier): string {
  switch (tier) {
    case "pepinillo_plus":
      return "Plus";
    case "everywhere_monthly":
    case "everywhere_annual":
      return "Everywhere";
    default:
      return "Gratis";
  }
}

export function friendlyError(e: unknown): string {
  if (e instanceof ApiError) {
    switch (e.code) {
      case "api_not_configured":
        return "Falta configurar el servidor (VITE_API_BASE_URL).";
      case "invalid_credentials":
        return "Correo o contraseña incorrectos.";
      case "email_not_verified":
        return "Verifica tu correo para continuar.";
      case "session_expired":
        return "Tu sesión caducó. Vuelve a entrar.";
      case "bad_response":
        return "Sin conexión con el servidor.";
    }
    if (e.status === 409) return "Ese correo ya tiene cuenta. Entra.";
    if (e.status === 429) return "Demasiados intentos. Espera un minuto.";
    if (e.status >= 500) return "El servidor falló. Inténtalo más tarde.";
    return e.message;
  }
  if (e instanceof TypeError) return "Sin conexión con el servidor.";
  return "Algo falló. Inténtalo de nuevo.";
}

export function AuthView({
  session,
  initialMode = "login",
  initialEmail = "",
  onAuthed,
  onGuest,
}: {
  session: Session;
  initialMode?: AuthMode;
  initialEmail?: string;
  onAuthed: () => void;
  onGuest: () => void;
}) {
  const [mode, setMode] = useState<AuthMode>(initialMode);
  const [name, setName] = useState("");
  const [email, setEmail] = useState(initialEmail);
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      if (e instanceof ApiError && e.code === "email_not_verified") {
        setNotice("Verifica tu correo para continuar.");
        setMode("verify");
      } else {
        setError(friendlyError(e));
      }
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>
          {mode === "login" && "Entra a Pepinillo"}
          {mode === "register" && "Crea tu cuenta"}
          {mode === "forgot" && "Recupera tu contraseña"}
          {mode === "reset" && "Nueva contraseña"}
          {mode === "verify" && "Verifica tu correo"}
        </h2>
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

      {(mode === "login" || mode === "register") && (
        <form
          style={{ marginTop: 12 }}
          onSubmit={(e) => {
            e.preventDefault();
            if (mode === "login") void run(async () => {
              await session.login(email.trim(), password);
              onAuthed();
            });
            else void run(async () => {
              await session.register(email.trim(), name.trim(), password);
              onAuthed();
            });
          }}
        >
          {mode === "register" && (
            <div className="field">
              <label htmlFor="auth-name">Nombre</label>
              <input id="auth-name" className="textinput" value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" required />
            </div>
          )}
          <div className="field">
            <label htmlFor="auth-email">Correo</label>
            <input id="auth-email" className="textinput" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
          </div>
          <div className="field">
            <label htmlFor="auth-pass">Contraseña{mode === "register" && " (mínimo 8 caracteres)"}</label>
            <input id="auth-pass" className="textinput" type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete={mode === "login" ? "current-password" : "new-password"} minLength={mode === "register" ? 8 : undefined} required />
          </div>
          <button className="btn" type="submit" disabled={busy} style={{ width: "100%" }}>
            {busy ? "Espera…" : mode === "login" ? "Entrar" : "Crear cuenta"}
          </button>
          {mode === "login" && (
            <p>
              <button type="button" className="linkbtn" onClick={() => { setMode("forgot"); setError(null); }}>
                Olvidé mi contraseña
              </button>
            </p>
          )}
        </form>
      )}

      {mode === "forgot" && (
        <form
          style={{ marginTop: 12 }}
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              await api.forgotPassword(email.trim());
              setNotice("Revisa tu correo: te enviamos un código.");
              setMode("reset");
            });
          }}
        >
          <div className="field">
            <label htmlFor="auth-email-f">Correo</label>
            <input id="auth-email-f" className="textinput" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
          </div>
          <button className="btn" type="submit" disabled={busy} style={{ width: "100%" }}>
            {busy ? "Enviando…" : "Enviar código"}
          </button>
        </form>
      )}

      {mode === "reset" && (
        <form
          style={{ marginTop: 12 }}
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              await api.resetPassword(email.trim(), code.trim(), newPassword);
              setPassword("");
              setCode("");
              setNewPassword("");
              setNotice("Contraseña cambiada. Entra con la nueva.");
              setMode("login");
            });
          }}
        >
          <div className="field">
            <label htmlFor="auth-email-r">Correo</label>
            <input id="auth-email-r" className="textinput" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
          </div>
          <div className="field">
            <label htmlFor="auth-code-r">Código</label>
            <input id="auth-code-r" className="textinput" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code" required />
          </div>
          <div className="field">
            <label htmlFor="auth-new">Nueva contraseña (mínimo 8)</label>
            <input id="auth-new" className="textinput" type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} autoComplete="new-password" minLength={8} required />
          </div>
          <button className="btn" type="submit" disabled={busy} style={{ width: "100%" }}>
            {busy ? "Guardando…" : "Cambiar contraseña"}
          </button>
        </form>
      )}

      {mode === "verify" && (
        <form
          style={{ marginTop: 12 }}
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              await api.verifyEmail(email.trim(), code.trim());
              await session.reload();
              onAuthed();
            });
          }}
        >
          <div className="field">
            <label htmlFor="auth-email-v">Correo</label>
            <input id="auth-email-v" className="textinput" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
          </div>
          <div className="field">
            <label htmlFor="auth-code-v">Código</label>
            <input id="auth-code-v" className="textinput" value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" autoComplete="one-time-code" required />
          </div>
          <button className="btn" type="submit" disabled={busy} style={{ width: "100%" }}>
            {busy ? "Verificando…" : "Verificar"}
          </button>
          <p>
            <button
              type="button"
              className="linkbtn"
              disabled={busy || !email.trim()}
              onClick={() => void run(async () => {
                await api.resendVerification(email.trim());
                setNotice("Código reenviado. Revisa tu correo.");
              })}
            >
              Reenviar código
            </button>
          </p>
        </form>
      )}

      <p className="auth-switch">
        {mode === "login" && (
          <>¿Sin cuenta? <button type="button" className="linkbtn" onClick={() => { setMode("register"); setError(null); }}>Crea una</button></>
        )}
        {mode === "register" && (
          <>¿Ya tienes? <button type="button" className="linkbtn" onClick={() => { setMode("login"); setError(null); }}>Entra</button></>
        )}
        {(mode === "forgot" || mode === "reset" || mode === "verify") && (
          <button type="button" className="linkbtn" onClick={() => { setMode("login"); setError(null); }}>Volver a entrar</button>
        )}
      </p>
      <p className="auth-switch">
        <button type="button" className="linkbtn" onClick={onGuest}>
          Seguir como invitado
        </button>
      </p>
    </div>
  );
}
