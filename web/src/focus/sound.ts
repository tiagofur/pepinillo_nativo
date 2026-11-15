/* Soundscapes — honest subset of SoundscapePickerView.
   The iPad ships recorded audio files; the web has no audio asset pipeline
   (dev storage is noop), so these ambiences are generated locally with
   WebAudio and labeled as such. No fake file names, no silent buttons. */

export type Soundscape = "none" | "rain" | "white";

export function parseSoundscape(raw: unknown): Soundscape {
  return raw === "rain" || raw === "white" ? raw : "none";
}

export const SOUNDSCAPES: { id: Soundscape; name: string }[] = [
  { id: "none", name: "Ninguno" },
  { id: "rain", name: "Lluvia" },
  { id: "white", name: "Blanco" },
];

function noiseBuffer(ctx: AudioContext, seconds = 3): AudioBuffer {
  const buf = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
  return buf;
}

/** Start a looping generated ambience. Returns its stop function. */
export function startAmbience(kind: Exclude<Soundscape, "none">): () => void {
  const noop = () => {};
  const w = window as unknown as {
    AudioContext?: typeof AudioContext;
    webkitAudioContext?: typeof AudioContext;
  };
  const Ctor = w.AudioContext ?? w.webkitAudioContext;
  if (!Ctor) return noop;
  try {
    const ctx = new Ctor();
    const src = ctx.createBufferSource();
    src.buffer = noiseBuffer(ctx);
    src.loop = true;
    const gain = ctx.createGain();
    gain.gain.value = 0.05;
    if (kind === "rain") {
      const filter = ctx.createBiquadFilter();
      filter.type = "lowpass";
      filter.frequency.value = 900;
      src.connect(filter);
      filter.connect(gain);
      gain.connect(ctx.destination);
    } else {
      src.connect(gain);
      gain.connect(ctx.destination);
    }
    src.start();
    return () => {
      try {
        src.stop();
      } catch {
        /* already stopped */
      }
      void ctx.close().catch(() => {});
    };
  } catch {
    return noop;
  }
}
