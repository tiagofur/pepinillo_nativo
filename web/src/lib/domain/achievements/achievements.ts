/**
 * Achievements — mirror of iOS Domain/Models/Achievement.swift:
 * First Focus, Week Warrior (7-day streak), Pomodoro Master (100 pomodoros),
 * Deep Diver (10 long sessions ≥45 min), Century Club (100 sessions),
 * Early Bird (10 sessions started before 8 AM).
 */

import type { FocusSession } from '$lib/domain/entities/types';
import { isWorkPhase } from '$lib/domain/stats/daily';
import { computeStreak, buildDailyStats } from '$lib/domain/stats/daily';

export type AchievementId =
	| 'firstFocus'
	| 'weekWarrior'
	| 'pomodoroMaster'
	| 'deepDiver'
	| 'centuryClub'
	| 'earlyBird';

export interface Achievement {
	id: AchievementId;
	/** i18n key suffix under achievements.<id>. */
	progress: number; // 0..1
	unlocked: boolean;
}

const DEEP_SESSION_MS = 45 * 60_000;
const EARLY_BIRD_HOUR = 8;

export function evaluateAchievements(sessions: FocusSession[], now: Date = new Date()): Achievement[] {
	const work = sessions.filter(
		(s) => s.status === 'completed' && s.startedAt && isWorkPhase(s.phase)
	);
	const completedCount = work.length;
	const pomodoroCount = work.filter((s) => s.mode === 'pomodoro').length;
	const deepCount = work.filter((s) => s.elapsedMs >= DEEP_SESSION_MS).length;
	const earlyCount = work.filter((s) => new Date(s.startedAt!).getHours() < EARLY_BIRD_HOUR).length;
	const streak = computeStreak(buildDailyStats(sessions, now), now);

	const mk = (id: AchievementId, value: number, target: number): Achievement => ({
		id,
		progress: Math.min(1, target > 0 ? value / target : 0),
		unlocked: value >= target
	});

	return [
		mk('firstFocus', completedCount >= 1 ? 1 : 0, 1),
		mk('weekWarrior', streak, 7),
		mk('pomodoroMaster', pomodoroCount, 100),
		mk('deepDiver', deepCount, 10),
		mk('centuryClub', completedCount, 100),
		mk('earlyBird', earlyCount, 10)
	];
}
