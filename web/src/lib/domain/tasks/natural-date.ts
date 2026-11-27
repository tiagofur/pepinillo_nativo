import { localDateKey } from './recurrence';

/**
 * Issue #994 (S1/S2): a planned date typed at the END of capture text.
 * Pure, on-device, no AI — the same grammar the iOS (TaskPlanning.swift,
 * NaturalDateParser) and Android (NaturalDateParser.kt) resolvers implement
 * from contracts/fixtures/natural-date-cases-994.json.
 *
 * Shared semantics (see odd/tasks/994-natural-dates.md):
 * - only the END of the text is interpreted; a morning-phrase guard blocks
 *   the parse («Café de la mañana» keeps its title);
 * - numeric dates are always day/month (dd/mm — never month/day), plus
 *   dd/mm/yyyy and ISO yyyy-mm-dd;
 * - the trailing punctuation mark and the preposition/article right before
 *   the date (el, del, para el, on, for, by, na, ...) travel with it;
 * - weekday == today falls to the next week; everything resolves against
 *   the local start of day;
 * - no match → the input is returned byte-identical with no date;
 * - a match that would leave an empty title is not a match.
 */

export interface NaturalDateParse {
	/** Original text minus the recognized span, re-trimmed. */
	title: string;
	/** Local day key (YYYY-MM-DD) of the planned day, or null. */
	plannedDate: string | null;
}

interface DatePhrase {
	phrase: string;
	kind: 'today' | 'tomorrow' | 'dayAfterTomorrow' | 'weekday';
	weekday?: number;
}

/** Every parent phrase precedes its suffixes («pasado mañana» before
 * «mañana», «segunda-feira» before «segunda») so the longer reading wins;
 * exact-suffix matching makes the rest of the order irrelevant. Keep this
 * order when porting the table to Android/iOS. */
const DATE_PHRASES: DatePhrase[] = [
	{ phrase: 'pasado mañana', kind: 'dayAfterTomorrow' },
	{ phrase: 'pasado manana', kind: 'dayAfterTomorrow' },
	{ phrase: 'day after tomorrow', kind: 'dayAfterTomorrow' },
	{ phrase: 'depois de amanhã', kind: 'dayAfterTomorrow' },
	{ phrase: 'depois de amanha', kind: 'dayAfterTomorrow' },
	{ phrase: 'segunda-feira', kind: 'weekday', weekday: 1 },
	{ phrase: 'segunda feira', kind: 'weekday', weekday: 1 },
	{ phrase: 'terça-feira', kind: 'weekday', weekday: 2 },
	{ phrase: 'terca-feira', kind: 'weekday', weekday: 2 },
	{ phrase: 'terça feira', kind: 'weekday', weekday: 2 },
	{ phrase: 'terca feira', kind: 'weekday', weekday: 2 },
	{ phrase: 'quarta-feira', kind: 'weekday', weekday: 3 },
	{ phrase: 'quarta feira', kind: 'weekday', weekday: 3 },
	{ phrase: 'quinta-feira', kind: 'weekday', weekday: 4 },
	{ phrase: 'quinta feira', kind: 'weekday', weekday: 4 },
	{ phrase: 'sexta-feira', kind: 'weekday', weekday: 5 },
	{ phrase: 'sexta feira', kind: 'weekday', weekday: 5 },
	{ phrase: 'miércoles', kind: 'weekday', weekday: 3 },
	{ phrase: 'miercoles', kind: 'weekday', weekday: 3 },
	{ phrase: 'sábado', kind: 'weekday', weekday: 6 },
	{ phrase: 'sabado', kind: 'weekday', weekday: 6 },
	{ phrase: 'amanhã', kind: 'tomorrow' },
	{ phrase: 'amanha', kind: 'tomorrow' },
	{ phrase: 'wednesday', kind: 'weekday', weekday: 3 },
	{ phrase: 'tuesday', kind: 'weekday', weekday: 2 },
	{ phrase: 'thursday', kind: 'weekday', weekday: 4 },
	{ phrase: 'saturday', kind: 'weekday', weekday: 6 },
	{ phrase: 'lunes', kind: 'weekday', weekday: 1 },
	{ phrase: 'martes', kind: 'weekday', weekday: 2 },
	{ phrase: 'jueves', kind: 'weekday', weekday: 4 },
	{ phrase: 'viernes', kind: 'weekday', weekday: 5 },
	{ phrase: 'domingo', kind: 'weekday', weekday: 7 },
	{ phrase: 'monday', kind: 'weekday', weekday: 1 },
	{ phrase: 'friday', kind: 'weekday', weekday: 5 },
	{ phrase: 'sunday', kind: 'weekday', weekday: 7 },
	{ phrase: 'segunda', kind: 'weekday', weekday: 1 },
	{ phrase: 'terça', kind: 'weekday', weekday: 2 },
	{ phrase: 'terca', kind: 'weekday', weekday: 2 },
	{ phrase: 'quarta', kind: 'weekday', weekday: 3 },
	{ phrase: 'quinta', kind: 'weekday', weekday: 4 },
	{ phrase: 'sexta', kind: 'weekday', weekday: 5 },
	{ phrase: 'mañana', kind: 'tomorrow' },
	{ phrase: 'manana', kind: 'tomorrow' },
	{ phrase: 'tomorrow', kind: 'tomorrow' },
	{ phrase: 'today', kind: 'today' },
	{ phrase: 'hoy', kind: 'today' },
	{ phrase: 'hoje', kind: 'today' }
];

/** Prepositions/articles that travel with the date. Longest-first. */
const STRIP_PHRASES = [
	'el próximo',
	'el proximo',
	'para el',
	'la próxima',
	'la proxima',
	'na próxima',
	'na proxima',
	'próxima',
	'proxima',
	'próximo',
	'proximo',
	'next',
	'del',
	'el',
	'on',
	'for',
	'by',
	'em',
	'na',
	'no',
	'para'
];

/** Phrases that mean a time of day, not a future day — they block the parse. */
const GUARD_PHRASES = [
	'de la mañana',
	'por la mañana',
	'esta mañana',
	'de manhã',
	'da manhã',
	'pela manhã',
	'esta manhã'
];

const TRAILING_PUNCT = /[.,!?]$/;

/** True when `lower` ends with `phrase` and the phrase starts at a word
 * boundary (start of text or after whitespace). */
function endsAtWordBoundary(lower: string, phrase: string): boolean {
	if (!lower.endsWith(phrase)) return false;
	const start = lower.length - phrase.length;
	if (start === 0) return true;
	const before = lower[start - 1];
	return /\s/.test(before);
}

/** Local noon of a y/m/d triple — noon never straddles a day boundary. */
function localNoon(year: number, month: number, day: number): Date {
	return new Date(year, month - 1, day, 12, 0, 0, 0);
}

/** Real-calendar check: JS rolls overflow dates over (Feb 31 → Mar 3). */
function isValidDay(year: number, month: number, day: number): boolean {
	const d = localNoon(year, month, day);
	return d.getFullYear() === year && d.getMonth() === month - 1 && d.getDate() === day;
}

export function parseNaturalDateSuffix(text: string, now: Date): NaturalDateParse {
	const trimmed = text.trim();
	if (trimmed.length === 0) return { title: trimmed, plannedDate: null };

	// The probe drops ONE trailing punctuation mark so «el viernes.» matches;
	// with no match the original text is returned untouched.
	let probe = trimmed;
	if (TRAILING_PUNCT.test(probe)) probe = probe.slice(0, -1).replace(/\s+$/, '');
	if (probe.length === 0) return { title: trimmed, plannedDate: null };
	const lowerProbe = probe.toLowerCase();

	const noMatch: NaturalDateParse = { title: trimmed, plannedDate: null };

	// Morning-of-day phrases are never dates.
	if (GUARD_PHRASES.some((g) => endsAtWordBoundary(lowerProbe, g))) return noMatch;

	// Empty title after stripping ⇒ not a match (the text IS the date only).
	const finish = (date: string | null, matchStart: number): NaturalDateParse => {
		let title = probe.slice(0, matchStart).replace(/\s+$/, '');
		const lowerTitle = title.toLowerCase();
		for (const strip of STRIP_PHRASES) {
			if (endsAtWordBoundary(lowerTitle, strip)) {
				title = title.slice(0, title.length - strip.length).replace(/\s+$/, '');
				break;
			}
		}
		if (title.length === 0) return noMatch;
		return { title, plannedDate: date };
	};

	// 1. Numeric dates (unambiguous) — ISO first, then dd/mm/yyyy, then dd/mm.
	let m = /(?:^|\s)(\d{4})-(\d{2})-(\d{2})$/.exec(probe);
	if (m) {
		const [, y, mo, d] = m;
		if (isValidDay(Number(y), Number(mo), Number(d))) {
			return finish(localDateKey(localNoon(Number(y), Number(mo), Number(d))), m.index);
		}
		return noMatch;
	}
	m = /(?:^|\s)(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(probe);
	if (m) {
		const [, d, mo, y] = m;
		if (isValidDay(Number(y), Number(mo), Number(d))) {
			return finish(localDateKey(localNoon(Number(y), Number(mo), Number(d))), m.index);
		}
		return noMatch;
	}
	m = /(?:^|\s)(\d{1,2})\/(\d{1,2})$/.exec(probe);
	if (m) {
		const day = Number(m[1]);
		const month = Number(m[2]);
		// Always the next real calendar day (S1): «29/2» lands on the next
		// leap year, never rolls over to March 1st and never stays in the past.
		const baseYear = now.getFullYear();
		let resolved: Date | null = null;
		for (let year = baseYear; year <= baseYear + 8; year += 1) {
			const candidate = isValidDay(year, month, day) ? localNoon(year, month, day) : null;
			if (candidate && candidate.getTime() >= startOfToday(now).getTime()) {
				resolved = candidate;
				break;
			}
		}
		if (!resolved) return noMatch;
		return finish(localDateKey(resolved), m.index);
	}

	// 2. Grammar phrases, longest-first.
	for (const candidate of DATE_PHRASES) {
		if (!endsAtWordBoundary(lowerProbe, candidate.phrase)) continue;
		const start = lowerProbe.length - candidate.phrase.length;
		return finish(resolvePhrase(candidate, now), start);
	}

	return noMatch;
}

function startOfToday(now: Date): Date {
	const d = new Date(now);
	d.setHours(0, 0, 0, 0);
	return d;
}

function resolvePhrase(candidate: DatePhrase, now: Date): string {
	const day = startOfToday(now);
	day.setHours(12, 0, 0, 0);
	switch (candidate.kind) {
		case 'today':
			break;
		case 'tomorrow':
			day.setDate(day.getDate() + 1);
			break;
		case 'dayAfterTomorrow':
			day.setDate(day.getDate() + 2);
			break;
		case 'weekday': {
			const isoToday = day.getDay() === 0 ? 7 : day.getDay();
			let delta = (candidate.weekday! - isoToday + 7) % 7;
			if (delta === 0) delta = 7; // weekday == today → next week (S1)
			day.setDate(day.getDate() + delta);
			break;
		}
	}
	return localDateKey(day);
}
