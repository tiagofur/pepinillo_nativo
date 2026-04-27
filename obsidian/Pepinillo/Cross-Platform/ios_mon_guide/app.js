const STORAGE_KEY = "pepinillo-ios-mon-guide-v1";

const checks = Array.from(document.querySelectorAll('input[type="checkbox"][data-id]'));
const meterFill = document.getElementById("meterFill");
const meterLabel = document.getElementById("meterLabel");
const resetBtn = document.getElementById("resetBtn");
const notesBox = document.getElementById("notesBox");
const copyBtn = document.getElementById("copyBtn");
const chips = Array.from(document.querySelectorAll(".chip"));
const steps = Array.from(document.querySelectorAll(".step"));

function getState() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return { checks: {}, notes: "" };
  }

  try {
    return JSON.parse(raw);
  } catch {
    return { checks: {}, notes: "" };
  }
}

function saveState() {
  const current = {
    checks: Object.fromEntries(checks.map((cb) => [cb.dataset.id, cb.checked])),
    notes: notesBox.value,
  };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(current));
}

function updateMeter() {
  const completed = checks.filter((cb) => cb.checked).length;
  const total = checks.length;
  const pct = total === 0 ? 0 : Math.round((completed / total) * 100);

  meterFill.style.width = `${pct}%`;
  meterLabel.textContent = `${pct}% completado (${completed}/${total} tareas)`;
}

function hydrate() {
  const state = getState();

  checks.forEach((cb) => {
    cb.checked = Boolean(state.checks[cb.dataset.id]);
  });

  notesBox.value = state.notes || "";
  updateMeter();
}

function applyFilter(filter) {
  steps.forEach((step) => {
    const owner = step.dataset.owner;
    const visible = filter === "all" || owner === filter;
    step.classList.toggle("hidden", !visible);
  });
}

checks.forEach((cb) => {
  cb.addEventListener("change", () => {
    updateMeter();
    saveState();
  });
});

notesBox.addEventListener("input", saveState);

resetBtn.addEventListener("click", () => {
  checks.forEach((cb) => {
    cb.checked = false;
  });
  notesBox.value = "";
  saveState();
  updateMeter();
});

chips.forEach((chip) => {
  chip.addEventListener("click", () => {
    chips.forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    applyFilter(chip.dataset.filter);
  });
});

copyBtn.addEventListener("click", async () => {
  const done = checks.filter((cb) => cb.checked).length;
  const total = checks.length;

  const pending = checks
    .filter((cb) => !cb.checked)
    .map((cb) => cb.closest("label")?.textContent?.trim())
    .filter(Boolean);

  const summary = [
    "Pepinillo iOS Monetization Guide — resumen",
    `Progreso: ${done}/${total}`,
    "",
    "Pendientes:",
    ...(pending.length ? pending.map((p) => `- ${p}`) : ["- Ninguno"]),
    "",
    "Notas:",
    notesBox.value || "(sin notas)",
  ].join("\n");

  try {
    await navigator.clipboard.writeText(summary);
    copyBtn.textContent = "Resumen copiado";
    setTimeout(() => {
      copyBtn.textContent = "Copiar resumen para ticket";
    }, 1400);
  } catch {
    copyBtn.textContent = "No se pudo copiar";
    setTimeout(() => {
      copyBtn.textContent = "Copiar resumen para ticket";
    }, 1400);
  }
});

hydrate();
