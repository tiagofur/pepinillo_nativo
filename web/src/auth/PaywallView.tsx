import { tierLabel } from "./AuthView";
import type { SubscriptionTier } from "../api/client";

/* Paywall — mirrors PaywallView + PaywallCommercialClaims copy.
   The web cannot sell App Store / Play products, so there is no fake buy
   button: purchase happens on device, and this screen activates from the
   server tier (GET /users/me) with an explicit refresh. */

const PLUS_FEATURES = [
  "Modos Flowtime y Bloque de tiempo",
  "Subtareas, recurrencia y analítica por tarea",
  "Exportación de tus datos",
  "Temas e informes locales",
];

const EVERYWHERE_FEATURES = [
  "Todo lo de Pepinillo+",
  "Sync con tu cuenta Pepinillo en todos tus aparatos",
  "Recuperación al volver a entrar",
];

export function PaywallView({
  tier,
  onRefresh,
}: {
  tier: SubscriptionTier | null;
  onRefresh: () => void;
}) {
  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>Pepinillo+</h2>
      </div>
      <p className="sub">
        Pepinillo+ desbloquea funciones premium locales. Everywhere incluye eso
        más sync y recuperación con tu cuenta.
      </p>

      <div className="card">
        <strong>Pepinillo+ · de por vida</strong>
        <p className="sub">Ideal para enfocarte en iPhone y iPad.</p>
        <ul className="sublist">
          {PLUS_FEATURES.map((f) => (
            <li key={f}>✓ {f}</li>
          ))}
        </ul>
        <p className="sub">No es suscripción.</p>
      </div>

      <div className="card">
        <strong>Everywhere · suscripción</strong>
        <p className="sub">Ideal si quieres sync y recuperación con tu cuenta.</p>
        <ul className="sublist">
          {EVERYWHERE_FEATURES.map((f) => (
            <li key={f}>✓ {f}</li>
          ))}
        </ul>
        <p className="sub">Suscripción auto-renovable. Requiere cuenta Pepinillo.</p>
      </div>

      <div className="card">
        <strong>Cómo desbloquear</strong>
        <p className="sub">
          La compra se hace en la app de iPhone o iPad. Esta web se activa sola
          con tu cuenta{tier ? ` (tu plan actual: ${tierLabel(tier)})` : ""}.
        </p>
        <div className="timer-actions" style={{ justifyContent: "flex-start" }}>
          <button className="btn" type="button" onClick={onRefresh}>
            Ya compré · recargar
          </button>
        </div>
      </div>

      <p className="sub" style={{ fontSize: 13 }}>
        Al continuar aceptas los términos de tu tienda de apps. Los precios se
        muestran en la App Store o Google Play.
      </p>
    </div>
  );
}
