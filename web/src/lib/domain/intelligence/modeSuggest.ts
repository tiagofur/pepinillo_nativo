import type { FocusMode } from '$lib/domain/entities/types';

export type ModeSuggestion = {
	mode: FocusMode;
	/** i18n key suffix under focus.suggest.* */
	reasonKey: 'morning' | 'deep' | 'afternoon' | 'evening' | 'flexible';
	/** Free users can apply only free modes; premium modes show as locked teaser */
	locked: boolean;
};

/**
 * Lightweight Mode Intelligence teaser (portable scoring stub for Free shell).
 * Mirrors product intent of mobile Mode Intelligence without full history model.
 */
export function suggestMode(now: Date = new Date()): ModeSuggestion {
	const hour = now.getHours();

	if (hour >= 6 && hour < 10) {
		return { mode: 'pomodoro', reasonKey: 'morning', locked: false };
	}
	if (hour >= 10 && hour < 13) {
		return { mode: 'flowtime', reasonKey: 'deep', locked: true };
	}
	if (hour >= 13 && hour < 17) {
		return { mode: 'timeblock', reasonKey: 'afternoon', locked: true };
	}
	if (hour >= 17 && hour < 21) {
		return { mode: 'pomodoro', reasonKey: 'evening', locked: false };
	}
	return { mode: 'stopwatch', reasonKey: 'flexible', locked: false };
}
