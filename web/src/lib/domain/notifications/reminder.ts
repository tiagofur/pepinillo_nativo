/**
 * Daily reminder scheduling — mirror of the native daily reminder
 * (hour/minute picker in Settings → Notifications).
 */

/** Milliseconds until the next fire of a daily HH:MM reminder (local time). */
export function msUntilNextFire(hour: number, minute: number, now: Date = new Date()): number {
	const target = new Date(now);
	target.setHours(clampHour(hour), clampMinute(minute), 0, 0);
	if (target.getTime() <= now.getTime()) {
		target.setDate(target.getDate() + 1);
	}
	return Math.max(0, target.getTime() - now.getTime());
}

export function clampHour(hour: number): number {
	return Math.min(23, Math.max(0, Math.round(hour || 0)));
}

export function clampMinute(minute: number): number {
	return Math.min(59, Math.max(0, Math.round(minute || 0)));
}
