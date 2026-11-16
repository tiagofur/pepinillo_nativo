import { describe, expect, it } from 'vitest';
import { suggestMode } from '$lib/domain/intelligence/modeSuggest';

describe('suggestMode', () => {
	it('suggests pomodoro in the morning (free)', () => {
		const s = suggestMode(new Date('2026-08-05T08:00:00'));
		expect(s.mode).toBe('pomodoro');
		expect(s.locked).toBe(false);
		expect(s.reasonKey).toBe('morning');
	});

	it('teases flowtime mid-morning as locked premium', () => {
		const s = suggestMode(new Date('2026-08-05T11:00:00'));
		expect(s.mode).toBe('flowtime');
		expect(s.locked).toBe(true);
	});

	it('suggests stopwatch late night (free)', () => {
		const s = suggestMode(new Date('2026-08-05T23:00:00'));
		expect(s.mode).toBe('stopwatch');
		expect(s.locked).toBe(false);
	});
});
