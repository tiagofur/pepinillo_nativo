/**
 * Recurrence presets and advancement — mirror of android
 * domain/tasks/RecurrenceCalculator.kt + the iOS TaskItem presets.
 * RRULE subset: FREQ (DAILY/WEEKLY/MONTHLY), INTERVAL, BYDAY.
 */

export type RecurrencePresetKey =
	| 'daily'
	| 'weekdays'
	| 'weekly'
	| 'biweekly'
	| 'monthly';

export interface RecurrencePreset {
	key: RecurrencePresetKey;
	rrule: string;
}

export const RECURRENCE_PRESETS: RecurrencePreset[] = [
	{ key: 'daily', rrule: 'FREQ=DAILY' },
	{ key: 'weekdays', rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR' },
	{ key: 'weekly', rrule: 'FREQ=WEEKLY' },
	{ key: 'biweekly', rrule: 'FREQ=WEEKLY;INTERVAL=2' },
	{ key: 'monthly', rrule: 'FREQ=MONTHLY' }
];

const WEEKDAYS = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

export function presetByKey(key: RecurrencePresetKey): RecurrencePreset | null {
	return RECURRENCE_PRESETS.find((p) => p.key === key) ?? null;
}

export interface ParsedRRule {
	freq: 'DAILY' | 'WEEKLY' | 'MONTHLY';
	interval: number;
	byday: string[];
}

export function parseRRule(rrule: string): ParsedRRule | null {
	const parts = rrule.split(';').map((p) => p.trim());
	let freq: ParsedRRule['freq'] | null = null;
	let interval = 1;
	let byday: string[] = [];
	for (const part of parts) {
		const [k, v] = part.split('=');
		if (k === 'FREQ' && (v === 'DAILY' || v === 'WEEKLY' || v === 'MONTHLY')) freq = v;
		else if (k === 'INTERVAL') {
			const n = Number(v);
			if (Number.isFinite(n) && n >= 1) interval = n;
		} else if (k === 'BYDAY') byday = v.split(',').map((d) => d.trim().toUpperCase());
	}
	return freq ? { freq, interval, byday } : null;
}

/** Local-day helpers (recurrence advances in device local time, like native). */
export function startOfLocalDay(d: Date): Date {
	return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function addDays(d: Date, days: number): Date {
	const out = startOfLocalDay(d);
	out.setDate(out.getDate() + days);
	return out;
}

function addMonths(d: Date, months: number): Date {
	const out = startOfLocalDay(d);
	const day = out.getDate();
	out.setMonth(out.getMonth() + months);
	// Clamp day-of-month overflow (Jan 31 + 1mo → Feb 28).
	if (out.getDate() < day) out.setDate(0);
	return out;
}

/**
 * Next occurrence strictly AFTER `after`. Native behavior: advancing a
 * series keeps stepping from the current due date (or today when absent).
 */
export function nextOccurrence(rrule: string, after: Date): Date | null {
	const parsed = parseRRule(rrule);
	if (!parsed) return null;
	const base = startOfLocalDay(after);

	if (parsed.freq === 'DAILY') return addDays(base, parsed.interval);

	if (parsed.freq === 'WEEKLY') {
		if (parsed.byday.length === 0) return addDays(base, 7 * parsed.interval);
		// Next matching weekday after `base`.
		for (let i = 1; i <= 7 * parsed.interval; i += 1) {
			const candidate = addDays(base, i);
			if (parsed.byday.includes(WEEKDAYS[candidate.getDay()])) return candidate;
		}
		return null;
	}

	// MONTHLY
	return addMonths(base, parsed.interval);
}

export interface RecurringAdvance {
	lastCompletedAt: string;
	nextDueDate: string | null;
}

/**
 * Compute the fields a recurring task takes when its occurrence completes:
 * the series stays alive (`lastCompletedAt`) and the next due date advances.
 */
export function advanceRecurring(
	recurrenceRule: string,
	currentDueDate: string | null,
	completedAt: Date = new Date()
): RecurringAdvance | null {
	const next = nextOccurrence(recurrenceRule, currentDueDate ? new Date(`${currentDueDate}T12:00:00`) : completedAt);
	return {
		lastCompletedAt: completedAt.toISOString(),
		nextDueDate: next ? localDateKey(next) : null
	};
}

/** YYYY-MM-DD local key (same convention as daily stats). */
export function localDateKey(d: Date): string {
	const y = d.getFullYear();
	const m = String(d.getMonth() + 1).padStart(2, '0');
	const day = String(d.getDate()).padStart(2, '0');
	return `${y}-${m}-${day}`;
}
