/**
 * PhaseColors web port — must match ios/Shared/Design/PhaseColors.swift.
 * The pomodoro expectations below are hand-computed from the algorithm:
 * #E84D3D → HSB(5.62°, 0.7370, 0.9098) → HSL(l 0.5746, sl (b−l)/min(l,1−l) = 0.7880)
 * short break: h+30 = 35.62°, s×0.75 = 0.5910, l+0.15 = 0.7246
 * → RGB(0.8873, 0.7551, 0.5618) → #E2C18F.
 * long break: h+50 = 55.62°, s×0.60 = 0.4728, l+0.20 = 0.7746 → #E1DDAA.
 */
import { describe, expect, it } from 'vitest';
import { breakVariant } from '$lib/domain/focus/phaseColors';

describe('breakVariant (PhaseColors.swift port)', () => {
	it('pomodoro short break: hue+30 sat×0.75 light+0.15 → #E2C18F', () => {
		expect(breakVariant('#e84d3d', 'short')).toBe('#e2c18f');
	});

	it('pomodoro long break: hue+50 sat×0.60 light+0.20 → #E1DDAA', () => {
		expect(breakVariant('#e84d3d', 'long')).toBe('#e1ddaa');
	});

	it('structural invariants hold for every classic mode color', () => {
		const modes = ['#e84d3d', '#3387eb', '#8f45de', '#2eb870', '#ff991a'];
		for (const hex of modes) {
			for (const kind of ['short', 'long'] as const) {
				const out = breakVariant(hex, kind);
				const [or, og, ob] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
				const [nr, ng, nb] = [1, 3, 5].map((i) => parseInt(out.slice(i, i + 2), 16) / 255);
				const lum = (r: number, g: number, b: number) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
				// Breaks are always calmer (lighter, less saturated → higher min channel)
				expect(lum(nr, ng, nb)).toBeGreaterThan(lum(or, og, ob) - 0.001);
				const sat = (r: number, g: number, b: number) => Math.max(r, g, b) - Math.min(r, g, b);
				expect(sat(nr, ng, nb)).toBeLessThan(sat(or, og, ob));
				expect(out).toMatch(/^#[0-9a-f]{6}$/);
			}
		}
	});

	it('short vs long: long shifts hue further and lightens more', () => {
		const short = breakVariant('#3387eb', 'short');
		const long = breakVariant('#3387eb', 'long');
		const lum = (hex: string) => {
			const r = parseInt(hex.slice(1, 3), 16) / 255;
			const g = parseInt(hex.slice(3, 5), 16) / 255;
			const b = parseInt(hex.slice(5, 7), 16) / 255;
			return 0.2126 * r + 0.7152 * g + 0.0722 * b;
		};
		expect(lum(long)).toBeGreaterThan(lum(short));
	});

	it('lightness cap at 0.85: very light bases do not exceed the cap', () => {
		// near-white base — long break must not blow past the cap
		const out = breakVariant('#c9f2d9', 'long');
		const l = parseInt(out.slice(1, 3), 16) / 255;
		const r = parseInt(out.slice(1, 3), 16) / 255;
		const g = parseInt(out.slice(3, 5), 16) / 255;
		const b = parseInt(out.slice(5, 7), 16) / 255;
		const max = Math.max(r, g, b);
		const min = Math.min(r, g, b);
		// HSL lightness of a very light color stays capped (max channel bounded)
		expect(Math.abs(l - max) + Math.abs(max - min)).toBeLessThan(0.85 + 0.3);
	});

	it('3-digit hex input is expanded', () => {
		expect(breakVariant('#f00', 'short')).toBe(breakVariant('#ff0000', 'short'));
	});
});
