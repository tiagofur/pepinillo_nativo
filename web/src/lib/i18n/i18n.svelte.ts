/**
 * Reactive i18n wrapper around the recovered message catalogs.
 * The catalogs (messages.ts) stay pure and testable; this module owns
 * the reactive locale and persistence. ES is the default (LATAM-first),
 * matching the native apps' es localization.
 */
import { detectLocale, t as translate, type MessageKey } from './messages';
import type { LocaleCode } from '$lib/domain/entities/types';
import { browser } from '$app/environment';

const LOCALE_KEY = 'pepinillo.locale';

let locale = $state<LocaleCode>('es');

export function initLocale(stored?: LocaleCode): void {
	if (stored) {
		locale = stored;
	} else {
		locale = detectLocale(browser ? navigator.language : 'es');
	}
	if (browser) {
		try {
			localStorage.setItem(LOCALE_KEY, locale);
		} catch {
			/* private mode — keep in-memory */
		}
	}
}

export function readStoredLocale(): LocaleCode | null {
	if (!browser) return null;
	try {
		const raw = localStorage.getItem(LOCALE_KEY);
		if (raw === 'en' || raw === 'es' || raw === 'pt') return raw;
	} catch {
		/* ignore */
	}
	return null;
}

export function setLocale(next: LocaleCode): void {
	locale = next;
	if (browser) {
		try {
			localStorage.setItem(LOCALE_KEY, next);
		} catch {
			/* ignore */
		}
	}
}

export function currentLocale(): LocaleCode {
	return locale;
}

/** Translate with optional {param} interpolation. */
export function t(key: MessageKey, params?: Record<string, string | number>): string {
	let text = translate(locale, key);
	if (params) {
		for (const [name, value] of Object.entries(params)) {
			text = text.replaceAll(`{${name}}`, String(value));
		}
	}
	return text;
}
