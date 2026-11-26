import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { planningBucket } from '$lib/domain/tasks/plan';
import { localDateKey } from '$lib/domain/tasks/recurrence';

/**
 * Issue #991 (S3): the unified «Hoy» rule asserted against the shared case
 * table versioned in the repo (contracts/fixtures/task-planning-cases-991.json)
 * — the same file the iOS (TaskPlanningTests) and Android suites decode.
 */
interface Expected {
	today: boolean;
	postponed: boolean;
	upcoming: boolean;
	inbox: boolean;
}

interface Case {
	name: string;
	planned: number | null;
	due: number | null;
	status: string;
	legacyScheduledForToday?: boolean;
	recurringInstance?: boolean;
	expected: Expected;
}

/** Local day key at noon of (base + offsetDays) — noon never crosses a day
 * boundary under day arithmetic; every call derives from the same base so a
 * midnight straddle mid-run cannot split the table (judgment A, r1). */
function dayKey(offsetDays: number, base: Date): string {
	const d = new Date(base);
	d.setDate(d.getDate() + offsetDays);
	d.setHours(12, 0, 0, 0);
	return localDateKey(d);
}

describe('unified planning rule against the shared case table (S3)', () => {
	const fixturePath = resolve(
		fileURLToPath(import.meta.url),
		'../../../../contracts/fixtures/task-planning-cases-991.json'
	);
	const cases: Case[] = JSON.parse(readFileSync(fixturePath, 'utf8')).cases;

	it('the shared table keeps growing with regressions', () => {
		expect(cases.length).toBeGreaterThanOrEqual(16);
	});

	it('every case matches the web resolver', () => {
		const now = new Date();
		for (const c of cases) {
			const planned = c.planned === null ? null : dayKey(c.planned, now);
			const due = c.due === null ? null : dayKey(c.due, now);
			const bucket = planningBucket(planned, due, c.legacyScheduledForToday ?? false, c.status, now);
			const label = c.name;
			if (bucket.kind === 'today') {
				expect(c.expected.today, `today — ${label}`).toBe(true);
				expect(bucket.postponed, `postponed — ${label}`).toBe(c.expected.postponed);
				expect(c.expected.upcoming, `not upcoming — ${label}`).toBe(false);
				expect(c.expected.inbox, `not inbox — ${label}`).toBe(false);
			} else if (bucket.kind === 'upcoming') {
				expect(c.expected.upcoming, `upcoming — ${label}`).toBe(true);
				expect(c.expected.today, `not today — ${label}`).toBe(false);
				expect(c.expected.inbox, `not inbox — ${label}`).toBe(false);
			} else if (bucket.kind === 'inbox') {
				expect(c.expected.inbox, `inbox — ${label}`).toBe(true);
				expect(c.expected.today, `not today — ${label}`).toBe(false);
				expect(c.expected.upcoming, `not upcoming — ${label}`).toBe(false);
			} else {
				expect(c.status, `completed only for completed — ${label}`).toBe('completed');
				expect(c.expected.today, `not today — ${label}`).toBe(false);
				expect(c.expected.upcoming, `not upcoming — ${label}`).toBe(false);
				expect(c.expected.inbox, `not inbox — ${label}`).toBe(false);
			}
		}
	});

	it('a past plan stays today and turns postponed after midnight (S6)', () => {
		const base = new Date();
		const yesterday = dayKey(-1, base);
		const todayBucket = planningBucket(yesterday, null, false, 'active');
		expect(todayBucket).toEqual({ kind: 'today', postponed: true });

		const tomorrow = new Date(base);
		tomorrow.setDate(tomorrow.getDate() + 1);
		const afterMidnight = planningBucket(yesterday, null, false, 'active', tomorrow);
		expect(afterMidnight).toEqual({ kind: 'today', postponed: true });
	});
});
