import { describe, expect, it } from 'vitest';
import { clampHour, clampMinute, msUntilNextFire } from '$lib/domain/notifications/reminder';

describe('msUntilNextFire', () => {
	const now = new Date(2026, 10, 16, 14, 30, 0); // 14:30 local

	it('fires today when the time is still ahead', () => {
		const ms = msUntilNextFire(16, 0, now);
		expect(ms).toBe(90 * 60_000);
	});

	it('rolls to tomorrow when the time already passed', () => {
		const ms = msUntilNextFire(9, 0, now);
		expect(ms).toBe((24 - 5.5) * 60 * 60_000);
	});

	it('fires exactly now → schedules tomorrow', () => {
		const ms = msUntilNextFire(14, 30, now);
		expect(ms).toBe(24 * 60 * 60_000);
	});

	it('clamps out-of-range values', () => {
		expect(clampHour(30)).toBe(23);
		expect(clampHour(-5)).toBe(0);
		expect(clampMinute(90)).toBe(59);
		expect(clampMinute(NaN)).toBe(0);
		const ms = msUntilNextFire(30, 90, now);
		expect(ms).toBeGreaterThan(0);
	});
});
