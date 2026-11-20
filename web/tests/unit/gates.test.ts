import { describe, expect, it } from 'vitest';
import {
	canCreateActiveTask,
	canExport,
	canUseAnalyticsPeriod,
	canUseMode,
	canUsePremiumTheme,
	canUseRecurrence,
	canUseSubtasks,
	canUseSync,
	filterSessionsForFreeAnalytics,
	maxActiveTasks,
	FREE_LIMITS
} from '$lib/domain/gates/freeLimits';
import { isSoundscapeFree } from '$lib/domain/audio/sounds';
import type { FocusMode, FocusSession, SoundscapeName } from '$lib/domain/entities/types';

describe('Free gates (PRD/04 §3.1)', () => {
	describe('isSoundscapeFree (tier-aware, #942 S6)', () => {
		const premium: SoundscapeName[] = ['ocean', 'fireplace', 'binaural', 'lofi'];
		const free: SoundscapeName[] = ['none', 'rain', 'forest', 'cafe', 'whiteNoise'];

		it('blocks premium soundscapes for Free', () => {
			for (const name of premium) expect(isSoundscapeFree(name, 'free')).toBe(false);
			for (const name of free) expect(isSoundscapeFree(name, 'free')).toBe(true);
		});

		it('unlocks every soundscape for Everywhere', () => {
			for (const name of [...premium, ...free]) {
				expect(isSoundscapeFree(name, 'everywhere')).toBe(true);
			}
		});

		it('stays backward compatible without a tier', () => {
			for (const name of premium) expect(isSoundscapeFree(name)).toBe(false);
		});
	});

	describe('canUseMode', () => {
		it('allows Pomodoro and Stopwatch for Free', () => {
			expect(canUseMode('pomodoro', 'free')).toBe(true);
			expect(canUseMode('stopwatch', 'free')).toBe(true);
		});

		it('blocks Flowtime and Time Block for Free', () => {
			expect(canUseMode('flowtime', 'free')).toBe(false);
			expect(canUseMode('timeblock', 'free')).toBe(false);
		});

		it('allows all modes for Everywhere', () => {
			const modes: FocusMode[] = ['pomodoro', 'stopwatch', 'flowtime', 'timeblock'];
			for (const mode of modes) {
				expect(canUseMode(mode, 'everywhere')).toBe(true);
			}
		});
	});

	describe('active task cap', () => {
		it('allows create when under Free cap of 3', () => {
			expect(canCreateActiveTask(0, 'free')).toBe(true);
			expect(canCreateActiveTask(2, 'free')).toBe(true);
		});

		it('blocks create when Free already has 3 active tasks', () => {
			expect(canCreateActiveTask(3, 'free')).toBe(false);
			expect(canCreateActiveTask(4, 'free')).toBe(false);
		});

		it('allows unlimited for Everywhere', () => {
			expect(canCreateActiveTask(3, 'everywhere')).toBe(true);
			expect(canCreateActiveTask(100, 'everywhere')).toBe(true);
			expect(maxActiveTasks('everywhere')).toBe(Infinity);
		});

		it('exposes Free max of 3', () => {
			expect(maxActiveTasks('free')).toBe(3);
			expect(FREE_LIMITS.maxActiveTasks).toBe(3);
		});
	});

	describe('structure gates', () => {
		it('blocks subtasks and recurrence on Free', () => {
			expect(canUseSubtasks('free')).toBe(false);
			expect(canUseRecurrence('free')).toBe(false);
		});

		it('allows subtasks and recurrence on Everywhere', () => {
			expect(canUseSubtasks('everywhere')).toBe(true);
			expect(canUseRecurrence('everywhere')).toBe(true);
		});
	});

	describe('analytics window', () => {
		it('keeps sessions within today + last 7 days for Free', () => {
			const now = new Date('2026-08-05T12:00:00.000Z');
			const sessions: FocusSession[] = [
				sessionAt('2026-08-05T10:00:00.000Z'),
				sessionAt('2026-07-30T10:00:00.000Z'), // day 6 back — keep
				sessionAt('2026-07-29T10:00:00.000Z'), // day 7 back — keep (inclusive window)
				sessionAt('2026-07-28T10:00:00.000Z') // day 8 — drop
			];
			const filtered = filterSessionsForFreeAnalytics(sessions, now);
			expect(filtered.map((s) => s.startedAt)).toEqual([
				'2026-08-05T10:00:00.000Z',
				'2026-07-30T10:00:00.000Z',
				'2026-07-29T10:00:00.000Z'
			]);
		});

		it('returns empty when no sessions in window', () => {
			const now = new Date('2026-08-05T12:00:00.000Z');
			const sessions = [sessionAt('2025-01-01T00:00:00.000Z')];
			expect(filterSessionsForFreeAnalytics(sessions, now)).toEqual([]);
		});
	});

	describe('premium surfaces', () => {
		it('blocks export, sync, premium themes on Free', () => {
			expect(canExport('free')).toBe(false);
			expect(canUseSync('free')).toBe(false);
			expect(canUsePremiumTheme('free')).toBe(false);
		});

		it('allows export, sync, premium themes on Everywhere', () => {
			expect(canExport('everywhere')).toBe(true);
			expect(canUseSync('everywhere')).toBe(true);
			expect(canUsePremiumTheme('everywhere')).toBe(true);
		});
	});

	describe('Pepinillo+ tier (#952 S1/S3)', () => {
		it('unlocks local premium: modes, cap, structure, export, themes, analytics', () => {
			const modes: FocusMode[] = ['pomodoro', 'stopwatch', 'flowtime', 'timeblock'];
			for (const mode of modes) expect(canUseMode(mode, 'pepinillo_plus')).toBe(true);
			expect(canCreateActiveTask(100, 'pepinillo_plus')).toBe(true);
			expect(maxActiveTasks('pepinillo_plus')).toBe(Infinity);
			expect(canUseSubtasks('pepinillo_plus')).toBe(true);
			expect(canUseRecurrence('pepinillo_plus')).toBe(true);
			expect(canExport('pepinillo_plus')).toBe(true);
			expect(canUsePremiumTheme('pepinillo_plus')).toBe(true);
			expect(canUseAnalyticsPeriod(30, 'pepinillo_plus')).toBe(true);
			expect(canUseAnalyticsPeriod(365, 'pepinillo_plus')).toBe(true);
		});

		it('does NOT unlock multi-device sync — Everywhere-only lane (#942)', () => {
			expect(canUseSync('pepinillo_plus')).toBe(false);
			expect(canUseSync('everywhere')).toBe(true);
		});

		it('unlocks premium soundscapes', () => {
			const premium: SoundscapeName[] = ['ocean', 'fireplace', 'binaural', 'lofi'];
			for (const name of premium) expect(isSoundscapeFree(name, 'pepinillo_plus')).toBe(true);
		});
	});
});

function sessionAt(iso: string): FocusSession {
	return {
		id: iso,
		mode: 'pomodoro',
		status: 'completed',
		startedAt: iso,
		elapsedMs: 1000,
		segmentStartedAt: null,
		targetMs: 25 * 60 * 1000,
		taskId: null,
		journal: '',
		completedAt: iso,
		createdAt: iso,
		updatedAt: iso
	};
}
