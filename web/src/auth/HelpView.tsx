/* Help & Support — mirrors HelpSupportView + HelpContent.
   Every link below comes verbatim from the iOS source of truth
   (HelpContent.swift); nothing here is invented. */

const LINKS = [
  { label: "Guía rápida", href: "https://creapolis.dev/proyectos/pepinillo/guide" },
  { label: "Consejos de enfoque", href: "https://creapolis.dev/proyectos/pepinillo/tips" },
  { label: "Enviar comentarios", href: "https://creapolis.dev/proyectos/pepinillo/feedback" },
  { label: "Creapolis en X", href: "https://x.com/creapolisdev" },
  { label: "Aviso de privacidad", href: "https://creapolis.dev/privacy-policy/" },
];

const FAQ = [
  {
    q: "¿Necesito cuenta?",
    a: "No para lo básico: el temporizador, las tareas y el panel funcionan en este navegador. La cuenta sirve para sincronizar entre aparatos y para Plus.",
  },
  {
    q: "¿Cómo consigo Plus?",
    a: "La compra se hace en la app de iPhone o iPad. Esta web se activa sola cuando tu cuenta tiene el plan.",
  },
  {
    q: "¿Dónde están mis datos?",
    a: "En este navegador hasta que sincronices. Puedes descargarlos en JSON o CSV desde tu perfil, y borrarlos desde Más.",
  },
  {
    q: "¿Llegan notificaciones con la pestaña cerrada?",
    a: "No: la web avisa con la pestaña abierta. En iPhone las programa el sistema.",
  },
  {
    q: "¿Funciona sin conexión?",
    a: "Sí. Todo lo local sigue funcionando y verás un aviso arriba.",
  },
];

export function HelpView() {
  return (
    <div>
      <div className="sheet-head">
        <h2 style={{ margin: 0 }}>Ayuda y soporte</h2>
      </div>
      {FAQ.map((item) => (
        <div key={item.q} className="card">
          <strong>{item.q}</strong>
          <p className="sub" style={{ marginBottom: 0 }}>
            {item.a}
          </p>
        </div>
      ))}
      <div className="card">
        <strong>Enlaces</strong>
        <ul className="sublist">
          {LINKS.map((l) => (
            <li key={l.href}>
              <span className="grow">
                <a href={l.href} target="_blank" rel="noreferrer">
                  {l.label}
                </a>
              </span>
            </li>
          ))}
          <li>
            <span className="grow">
              <a href="mailto:hola@creapolis.dev">hola@creapolis.dev</a>
            </span>
          </li>
        </ul>
      </div>
    </div>
  );
}
