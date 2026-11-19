/**
 * WebAudio: completion sounds (fully synthesized) and procedural
 * soundscapes — no assets, no network, autoplay-policy safe (every
 * entry point must be called from a user gesture or after one).
 *
 * Mirror of the native catalogs: CompletionSound.swift (5 sounds) and
 * Soundscape.kt (8 soundscapes; 4 free, 4 premium).
 */

import type { CompletionSoundName, SoundscapeName } from '$lib/domain/entities/types';

let ctx: AudioContext | null = null;

function audioContext(): AudioContext | null {
	if (typeof window === 'undefined') return null;
	const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
	if (!Ctor) return null;
	if (!ctx) ctx = new Ctor();
	if (ctx.state === 'suspended') void ctx.resume();
	return ctx;
}

/** Call once from a user gesture so later programmatic playback is allowed. */
export function primeAudio(): void {
	audioContext();
}

// ---------- Completion sounds ----------

function tone(
	ac: AudioContext,
	dest: AudioNode,
	freq: number,
	startAt: number,
	durMs: number,
	type: OscillatorType = 'sine',
	gainPeak = 0.25
): void {
	const osc = ac.createOscillator();
	const gain = ac.createGain();
	osc.type = type;
	osc.frequency.value = freq;
	gain.gain.setValueAtTime(0, startAt);
	gain.gain.linearRampToValueAtTime(gainPeak, startAt + 0.012);
	gain.gain.exponentialRampToValueAtTime(0.0001, startAt + durMs / 1000);
	osc.connect(gain).connect(dest);
	osc.start(startAt);
	osc.stop(startAt + durMs / 1000 + 0.05);
}

/** Play a completion sound at `volume` (0..1). Returns duration ms. */
export function playCompletionSound(name: CompletionSoundName, volume = 1): number {
	const ac = audioContext();
	if (!ac || volume <= 0) return 0;
	const master = ac.createGain();
	master.gain.value = Math.min(1, Math.max(0, volume));
	master.connect(ac.destination);
	const t = ac.currentTime + 0.02;

	switch (name) {
		case 'classic': {
			// Two-tone friendly ding (660→880).
			tone(ac, master, 660, t, 220, 'sine', 0.3);
			tone(ac, master, 880, t + 0.12, 420, 'sine', 0.3);
			return 600;
		}
		case 'chime': {
			// Ascending triad with soft decay.
			tone(ac, master, 523.25, t, 500, 'sine', 0.22);
			tone(ac, master, 659.25, t + 0.14, 500, 'sine', 0.22);
			tone(ac, master, 783.99, t + 0.28, 700, 'sine', 0.22);
			return 1100;
		}
		case 'bell': {
			// Bell-ish: fundamental + inharmonic partial, long decay.
			tone(ac, master, 587.33, t, 1400, 'sine', 0.26);
			tone(ac, master, 1479.98, t, 900, 'sine', 0.08);
			tone(ac, master, 2200, t, 500, 'sine', 0.05);
			return 1500;
		}
		case 'digital': {
			// Crisp double beep.
			tone(ac, master, 1046.5, t, 90, 'square', 0.12);
			tone(ac, master, 1046.5, t + 0.16, 160, 'square', 0.12);
			return 420;
		}
		case 'woodblock': {
			// Percussive click: short triangle burst through a bandpass.
			const osc = ac.createOscillator();
			const filter = ac.createBiquadFilter();
			const gain = ac.createGain();
			osc.type = 'triangle';
			osc.frequency.setValueAtTime(1100, t);
			osc.frequency.exponentialRampToValueAtTime(500, t + 0.06);
			filter.type = 'bandpass';
			filter.frequency.value = 900;
			filter.Q.value = 1.5;
			gain.gain.setValueAtTime(0.5, t);
			gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
			osc.connect(filter).connect(gain).connect(master);
			osc.start(t);
			osc.stop(t + 0.2);
			return 240;
		}
	}
	return 400;
}

// ---------- Soundscapes (procedural loops) ----------

export const FREE_SOUNDSCAPES: readonly SoundscapeName[] = [
	'none',
	'rain',
	'forest',
	'cafe',
	'whiteNoise'
] as const;

export function isSoundscapeFree(name: SoundscapeName, tier?: 'free' | 'everywhere'): boolean {
	if (tier && tier !== 'free') return true;
	return FREE_SOUNDSCAPES.includes(name);
}

interface SoundscapeHandle {
	stop(): void;
	setVolume(v: number): void;
}

function noiseBuffer(ac: AudioContext, seconds = 2): AudioBuffer {
	const buffer = ac.createBuffer(1, ac.sampleRate * seconds, ac.sampleRate);
	const data = buffer.getChannelData(0);
	let last = 0;
	for (let i = 0; i < data.length; i += 1) {
		const white = Math.random() * 2 - 1;
		// Brown-ish base: heavy low-pass on white noise.
		last = (last + 0.02 * white) / 1.02;
		data[i] = last * 3.2;
	}
	return buffer;
}

function scheduleRandomChirps(
	ac: AudioContext,
	dest: AudioNode,
	opts: { minGapMs: number; maxGapMs: number; baseFreq: number; sweepMs: number; type: OscillatorType; gain: number }
): () => void {
	let alive = true;
	const schedule = () => {
		if (!alive) return;
		const gap = opts.minGapMs + Math.random() * (opts.maxGapMs - opts.minGapMs);
		setTimeout(() => {
			if (!alive) return;
			const t = ac.currentTime + 0.01;
			const osc = ac.createOscillator();
			const g = ac.createGain();
			osc.type = opts.type;
			osc.frequency.setValueAtTime(opts.baseFreq * (0.85 + Math.random() * 0.4), t);
			osc.frequency.linearRampToValueAtTime(
				opts.baseFreq * (1.2 + Math.random() * 0.5),
				t + opts.sweepMs / 1000
			);
			g.gain.setValueAtTime(0, t);
			gainRamp(g, t, opts.gain, opts.sweepMs);
			osc.connect(g).connect(dest);
			osc.start(t);
			osc.stop(t + (opts.sweepMs + 120) / 1000);
			schedule();
		}, gap);
	};
	schedule();
	return () => {
		alive = false;
	};
}

function gainRamp(g: GainNode, t: number, peak: number, ms: number): void {
	g.gain.linearRampToValueAtTime(peak, t + ms * 0.35 / 1000);
	g.gain.linearRampToValueAtTime(0, t + ms / 1000);
}

/** Start a soundscape loop. Returns null when unsupported/none. */
export function startSoundscape(
	name: SoundscapeName,
	volume = 0.5
): SoundscapeHandle | null {
	const ac = audioContext();
	if (!ac || name === 'none' || volume <= 0) return null;

	const master = ac.createGain();
	master.gain.value = Math.min(1, Math.max(0, volume));
	master.connect(ac.destination);
	const cleanups: (() => void)[] = [];
	const src: AudioBufferSourceNode | null = null;

	const startNoise = (filterType: BiquadFilterType, freq: number, Q = 0.7) => {
		const s = ac.createBufferSource();
		s.buffer = noiseBuffer(ac);
		s.loop = true;
		const f = ac.createBiquadFilter();
		f.type = filterType;
		f.frequency.value = freq;
		f.Q.value = Q;
		s.connect(f).connect(master);
		s.start();
		cleanups.push(() => s.stop());
		return { s, f };
	};

	switch (name) {
		case 'whiteNoise':
			startNoise('lowpass', 4500);
			break;
		case 'rain': {
			// Steady wash + droplet patter.
			startNoise('bandpass', 1600, 0.5);
			cleanups.push(
				scheduleRandomChirps(ac, master, {
					minGapMs: 60,
					maxGapMs: 260,
					baseFreq: 2400,
					sweepMs: 70,
					type: 'sine',
					gain: 0.03
				})
			);
			break;
		}
		case 'forest': {
			// Gentle breeze + sparse bird chirps.
			startNoise('lowpass', 700);
			cleanups.push(
				scheduleRandomChirps(ac, master, {
					minGapMs: 1400,
					maxGapMs: 4200,
					baseFreq: 2100,
					sweepMs: 180,
					type: 'sine',
					gain: 0.045
				})
			);
			break;
		}
		case 'cafe': {
			// Murmur: band-limited rumble with occasional clink.
			startNoise('bandpass', 420, 0.9);
			cleanups.push(
				scheduleRandomChirps(ac, master, {
					minGapMs: 2600,
					maxGapMs: 7000,
					baseFreq: 3800,
					sweepMs: 60,
					type: 'triangle',
					gain: 0.02
				})
			);
			break;
		}
		case 'ocean': {
			// Waves: slow LFO on lowpass noise gain.
			const { s, f } = startNoise('lowpass', 900);
			const lfo = ac.createOscillator();
			const lfoGain = ac.createGain();
			lfo.frequency.value = 0.09;
			lfoGain.gain.value = 0.45;
			lfo.connect(lfoGain).connect(master.gain);
			lfo.start();
			f.Q.value = 0.4;
			cleanups.push(() => s.stop(), () => lfo.stop());
			break;
		}
		case 'fireplace': {
			// Low body + random crackles.
			startNoise('lowpass', 340);
			cleanups.push(
				scheduleRandomChirps(ac, master, {
					minGapMs: 180,
					maxGapMs: 900,
					baseFreq: 1400,
					sweepMs: 30,
					type: 'square',
					gain: 0.018
				})
			);
			break;
		}
		case 'binaural': {
			// 6 Hz beat: 200 Hz left / 206 Hz right (headphones required).
			const merger = ac.createChannelMerger(2);
			const oL = ac.createOscillator();
			const oR = ac.createOscillator();
			oL.frequency.value = 200;
			oR.frequency.value = 206;
			oL.connect(merger, 0, 0);
			oR.connect(merger, 0, 1);
			merger.connect(master);
			oL.start();
			oR.start();
			cleanups.push(() => oL.stop(), () => oR.stop());
			break;
		}
		case 'lofi': {
			// Detuned chord pad + vinyl crackle.
			const chords = [220, 277.18, 329.63]; // A3, C#4, E4-ish, slightly detuned
			for (const [i, freq] of chords.entries()) {
				const o = ac.createOscillator();
				const g = ac.createGain();
				o.type = 'triangle';
				o.frequency.value = freq * (1 + (i % 2 === 0 ? 0.004 : -0.004));
				g.gain.value = 0.05;
				o.connect(g).connect(master);
				o.start();
				cleanups.push(() => o.stop());
			}
			cleanups.push(
				scheduleRandomChirps(ac, master, {
					minGapMs: 90,
					maxGapMs: 400,
					baseFreq: 5200,
					sweepMs: 24,
					type: 'sine',
					gain: 0.012
				})
			);
			break;
		}
	}

	void src;
	return {
		stop() {
			for (const fn of cleanups) fn();
			master.gain.setValueAtTime(0, ac.currentTime);
			setTimeout(() => master.disconnect(), 120);
		},
		setVolume(v: number) {
			master.gain.value = Math.min(1, Math.max(0, v));
		}
	};
}

// ---------- Haptics (Android vibration) ----------

export function haptic(pattern: 'tick' | 'success' | 'celebrate' = 'tick'): void {
	if (typeof navigator === 'undefined' || !('vibrate' in navigator)) return;
	const patterns: Record<string, number | number[]> = {
		tick: 10,
		success: [40, 60, 40],
		celebrate: [60, 50, 60, 50, 120]
	};
	navigator.vibrate(patterns[pattern]);
}

export type { SoundscapeHandle };
