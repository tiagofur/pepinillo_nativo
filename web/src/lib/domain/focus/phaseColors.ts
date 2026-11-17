/**
 * Break-phase color derivation — web port of ios/Shared/Design/PhaseColors.swift.
 * Derives calmer break colors from the base mode color by shifting hue,
 * reducing saturation and raising lightness (HSB → HSL → shift → back).
 * Pure logic: hex in, hex out. Mirrors the Mac app exactly so both
 * platforms render identical break colors for the same mode.
 */

export type BreakKind = 'short' | 'long';

/** AppTheme.classic fallbacks — runtime values resolve from CSS vars (themes). */
export const CLASSIC_MODE_HEX: Record<string, string> = {
	pomodoro: '#e84d3d',
	flowtime: '#3387eb',
	timeblock: '#8f45de',
	stopwatch: '#2eb870'
};

const SHORT_BREAK = { hueShift: 30, satFactor: 0.75, lightDelta: 0.15 } as const;
const LONG_BREAK = { hueShift: 50, satFactor: 0.6, lightDelta: 0.2 } as const;
const LIGHTNESS_CAP = 0.85;

function clamp01(v: number): number {
	return Math.min(1, Math.max(0, v));
}

function hexToRgb(hex: string): [number, number, number] {
	const h = hex.replace('#', '').trim();
	const full =
		h.length === 3
			? h
					.split('')
					.map((c) => c + c)
					.join('')
			: h;
	const int = parseInt(full, 16);
	return [(int >> 16) & 255, (int >> 8) & 255, int & 255];
}

function rgbToHex(r: number, g: number, b: number): string {
	const to = (v: number) =>
		Math.round(clamp01(v) * 255)
			.toString(16)
			.padStart(2, '0');
	return `#${to(r)}${to(g)}${to(b)}`;
}

/** RGB (0–1) → HSB/HSV {h: deg 0–360, s, b}. */
function rgbToHsb(r: number, g: number, b: number): { h: number; s: number; b: number } {
	const max = Math.max(r, g, b);
	const min = Math.min(r, g, b);
	const d = max - min;
	let h = 0;
	if (d !== 0) {
		if (max === r) h = (60 * ((g - b) / d)) % 360;
		else if (max === g) h = 60 * ((b - r) / d + 2);
		else h = 60 * ((r - g) / d + 4);
	}
	if (h < 0) h += 360;
	return { h, s: max === 0 ? 0 : d / max, b: max };
}

/** HSB → HSL (matches PhaseColors.swift: l = b·(1−s/2), sl = (b−l)/min(l,1−l)). */
function hsbToHsl(h: number, s: number, b: number): { h: number; sl: number; l: number } {
	const l = b * (1 - s / 2);
	const sl = l === 0 || l === 1 ? 0 : (b - l) / Math.min(l, 1 - l);
	return { h, sl, l };
}

/** HSL → RGB (0–1). */
function hslToRgb(h: number, sl: number, l: number): [number, number, number] {
	const c = (1 - Math.abs(2 * l - 1)) * sl;
	const hp = ((h % 360) + 360) % 360 / 60;
	const x = c * (1 - Math.abs((hp % 2) - 1));
	let r = 0;
	let g = 0;
	let b = 0;
	if (hp < 1) [r, g, b] = [c, x, 0];
	else if (hp < 2) [r, g, b] = [x, c, 0];
	else if (hp < 3) [r, g, b] = [0, c, x];
	else if (hp < 4) [r, g, b] = [0, x, c];
	else if (hp < 5) [r, g, b] = [x, 0, c];
	else [r, g, b] = [c, 0, x];
	const m = l - c / 2;
	return [r + m, g + m, b + m];
}

/**
 * Derive the break color for a base mode color, exactly like
 * Color.breakVariant(for:): short/flow break = hue+30°, sat×0.75,
 * light+0.15; long break = hue+50°, sat×0.60, light+0.20 (both capped at
 * lightness 0.85). Non-break phases return the base color unchanged.
 */
export function breakVariant(baseHex: string, kind: BreakKind): string {
	const [r, g, b] = hexToRgb(baseHex);
	const hsb = rgbToHsb(r / 255, g / 255, b / 255);
	const hsl = hsbToHsl(hsb.h, hsb.s, hsb.b);
	const rule = kind === 'short' ? SHORT_BREAK : LONG_BREAK;
	const newH = (hsl.h + rule.hueShift) % 360;
	const newS = hsl.sl * rule.satFactor;
	const newL = Math.min(hsl.l + rule.lightDelta, LIGHTNESS_CAP);
	const [nr, ng, nb] = hslToRgb(newH, newS, newL);
	return rgbToHex(nr, ng, nb);
}
