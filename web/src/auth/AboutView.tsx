import { tierLabel } from "./AuthView";
import type { Session } from "./useSession";

/* About — mirrors AboutView: identity, subscription row, legal, copyright.
   Web has no numeric app version yet (versioning starts at the first tag),
   so it says so instead of inventing one. The privacy URL is the real one
   from HelpContent.swift; there is no terms URL in the codebase, so none
   is linked. */

export function AboutView({ session }: { session: Session }) {
  const year = new Date().getFullYear();
  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>Acerca de</h2>
      </div>
      <div className="card" style={{ textAlign: "center" }}>
        <div className="brand" style={{ justifyContent: "center", paddingBottom: 8 }}>
          <span className="brand-dot">P</span> Pepinillo
        </div>
        <p className="sub" style={{ margin: 0 }}>
          Compañero de enfoque profundo
          <br />
          Edición web · paridad iPad
        </p>
      </div>
      <div className="card">
        <strong>Suscripción</strong>
        <p className="sub" style={{ marginBottom: 0 }}>
          {session.user
            ? `${tierLabel(session.user.subscriptionTier)} · ${session.user.aiCreditsBalance} créditos IA`
            : "Pepinillo Free (invitado)"}
        </p>
      </div>
      <div className="card">
        <strong>Legal</strong>
        <ul className="sublist">
          <li>
            <span className="grow">
              <a href="https://creapolis.dev/privacy-policy/" target="_blank" rel="noreferrer">
                Aviso de privacidad
              </a>
            </span>
          </li>
        </ul>
        <p className="sub" style={{ marginBottom: 0 }}>
          © {year} Creapolis Dev
        </p>
      </div>
    </div>
  );
}
