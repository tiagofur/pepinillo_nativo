import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { parseNaturalDateSuffix, parsedQuickAddOverrides } from '$lib/domain/tasks/natural-date';
import { localDateKey } from '$lib/domain/tasks/recurrence';

/**
 * Issue #994 (S1/S2): the natural-language planned-date grammar asserted
 * against the shared case table versioned in the repo
 * (contracts/fixtures/natural-date-cases-994.json) — the same file the iOS
 * (NaturalDateParserTests) and Android (NaturalDateParserFixtureTest) suites
 * decode. `fixedNow` is built in the LOCAL timezone of the test runner.
 */
interface ExpectedDate {
	kind: 'nextWeekday' | 'explicit';
	weekday?: number;
	year?: number;
	month?: number;
	day?: number;
}

interface Case {
	name: string;
	input: string;
	expectedTitle: string;
	expectedDate: string | ExpectedDate | null;
}

interface Fixture {
	fixedNow: { year: number; month: number; day: number; hour: number; minute: number };
	cases: Case[];
}

/** Local noon of a y/m/d triple — noon never straddles a day boundary. */
function localNoon(year: number, month: number, day: number): Date {
	return new Date(year, month - 1, day, 12, 0, 0, 0);
}

/** Resolve the fixture's symbolic expectation against the shared fixedNow. */
function expectedDayKey(expected: Case['expectedDate'], now: Date): string | null {
	if (expected === null) return null;
	if (typeof expected === 'string') {
		const d = new Date(now);
		d.setHours(12, 0, 0, 0);
		if (expected === 'today') return localDateKey(d);
		if (expected === 'tomorrow') d.setDate(d.getDate() + 1);
		if (expected === 'dayAfterTomorrow') d.setDate(d.getDate() + 2);
		return localDateKey(d);
	}
	if (expected.kind === 'explicit') {
		return localDateKey(localNoon(expected.year!, expected.month!, expected.day!));
	}
	// nextWeekday: next occurrence strictly after today; today → next week.
	const d = new Date(now);
	d.setHours(12, 0, 0, 0);
	const isoToday = d.getDay() === 0 ? 7 : d.getDay();
	let delta = (expected.weekday! - isoToday + 7) % 7;
	if (delta === 0) delta = 7;
	d.setDate(d.getDate() + delta);
	return localDateKey(d);
}

describe('natural date grammar against the shared case table (#994 S1/S2)', () => {
	const fixturePath = resolve(
		fileURLToPath(import.meta.url),
		'../../../../contracts/fixtures/natural-date-cases-994.json'
	);
	const fixture: Fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
	const now = localNoon(
		fixture.fixedNow.year,
		fixture.fixedNow.month,
		fixture.fixedNow.day
	);

	it('the shared table keeps the whole grammar covered', () => {
		expect(fixture.cases.length).toBeGreaterThanOrEqual(44);
	});

	it('every case matches the web parser', () => {
		for (const c of fixture.cases) {
			const result = parseNaturalDateSuffix(c.input, now);
			expect(result.title, `title — ${c.name}`).toBe(c.expectedTitle);
			expect(
				result.plannedDate,
				`plannedDate — ${c.name}`
			).toBe(expectedDayKey(c.expectedDate, now));
		}
	});

	it('a capture without a trailing date is byte-identical to the input', () => {
		const raw = '  Reunión lunes de estrategia  ';
		const result = parseNaturalDateSuffix(raw, now);
		expect(result.plannedDate).toBeNull();
		expect(result.title).toBe('Reunión lunes de estrategia');
	});
});

describe('parsedQuickAddOverrides — the quick-add wiring seam (#994 PR-d)', () => {
	const now = localNoon(2026, 11, 27);

	it('a trailing date yields the cleaned title and the pill override with the derived flag', () => {
		const { title, overrides } = parsedQuickAddOverrides('Enviar informe el viernes', now);
		expect(title).toBe('Enviar informe');
		expect(overrides.plannedDate).toBe('2026-12-04');
		expect(overrides.scheduledForToday).toBe(false);
	});

	it('a date parsed today keeps the legacy flag true', () => {
		const { overrides } = parsedQuickAddOverrides('Enviar informe hoy', now);
		expect(overrides.plannedDate).toBe('2026-11-27');
		expect(overrides.scheduledForToday).toBe(true);
	});

	it('no match keeps the input as the title and adds no override', () => {
		const { title, overrides } = parsedQuickAddOverrides('Viernes de rollout', now);
		expect(title).toBe('Viernes de rollout');
		expect(overrides).toEqual({});
	});
});
