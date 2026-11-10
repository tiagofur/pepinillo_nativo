# Pepinillo — Lecciones aprendidas de producto

## Propósito

Captura las lecciones estratégicas de la evolución de Pepinillo. No es una
especificación técnica: preserva el contexto de producto y el razonamiento de
decisiones para contribuidores y agentes de IA futuros.

---

# Origen

Pepinillo empezó como una app Flutter temprana y se convirtió en un proyecto
personal importante. La decisión de reconstruirlo nativo no se tomó porque
Flutter fuera insuficiente, sino porque la dirección del producto evolucionó
hacia integración profunda con el sistema operativo.

Las implementaciones nativas permiten a Pepinillo integrarse mejor con:
- Widgets de iOS
- Live Activities
- Dynamic Island
- Apple Watch
- Siri/App Intents
- Widgets de Android
- Wear OS
- Comportamiento de ciclo de vida por plataforma

El objetivo no era una migración de tecnología. El objetivo era una mejor
experiencia de producto.

---

# Qué funcionó bien

## Construir una base técnica sólida

Pepinillo se construyó con calidad de producción en mente:
- arquitectura nativa móvil;
- testing automatizado;
- pipelines CI/CD;
- separación del backend;
- arquitectura de billing;
- desarrollo documentado primero.

Esta base reduce el riesgo futuro del producto.

## Enfocarse en la experiencia core

Lo más valioso de Pepinillo no es el gestor de tareas ni la pantalla de
analíticas. Es ayudar a la gente a entrar y mantener trabajo enfocado.

El bucle core es:

```
Plan → Focus → Complete → Reflect
```

Las decisiones futuras deben proteger este bucle.

---

# Qué podría haber sido mejor

## Validar el producto antes

Una trampa común es mejorar el producto antes de validar si los usuarios lo
necesitan. Pepinillo ya tiene funcionalidad suficiente para validar el
mercado. La siguiente fase debe priorizar usuarios, retención, feedback y
señales de monetización — no simplemente más features.

---

# Lecciones de expansión de plataformas

Los experimentos de Windows y Web valieron la pena porque respondieron
preguntas técnicas: probaron viabilidad. Pero la expansión de plataformas debe
seguir la demanda de usuarios, no solo la posibilidad técnica.

Prioridad actual:

```
crecimiento Android + iOS

antes que

plataformas adicionales
```

---

# Lección de estrategia IA

La IA debe potenciar la misión de Pepinillo, no reemplazarla. Pepinillo no es
una aplicación de IA: es una aplicación de foco que usa IA donde genera valor
real (reflection, insights, planificación, coaching). La IA on-device
(Foundation Models con fallback de plantilla) pertenece a Pepinillo+; la IA
cloud (créditos) a Everywhere/AI+ (`docs/prd-v2.md` §6).

---

# Regla estratégica de aquí adelante

Antes de añadir una feature mayor, preguntar:

> ¿Esto mejora activación, retención o ingresos?

Si la respuesta no es clara, la feature probablemente deba esperar.

---

# Misión del producto

Pepinillo existe para ayudar a la gente a hacer trabajo significativo con
menos distracción.

La tecnología es la herramienta.

El foco es el producto.
