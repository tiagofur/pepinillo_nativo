/**
 * Plan filters and grouping — pure helpers behind the Plan page.
 * Pills mirror the Mac sidebar (MacPlanFilter): All / Today / Upcoming /
 * Completed. `inbox` stays a valid filter for the capture flow.
 */

import type { Preferences, Task, TaskEnergy } from '$lib/domain/entities/types';
import { ENERGY_ORDER } from './energy';
import { localDateKey } from './recurrence';

export type PlanFilter = Preferences['planFilter'];

export const PLAN_FILTERS: readonly PlanFilter[] = ['today', 'inbox', 'upcoming', 'completed'] as const;

const PLAN_FILTER_IDS: readonly PlanFilter[] = ['all', 'today', 'inbox', 'upcoming', 'completed'];

/** Stored prefs may predate the field or carry legacy values — fail closed to
 * the Mac default instead of feeding filterTasks an unknown filter (#975). */
export function restorePlanFilter(value: unknown): PlanFilter {
	return PLAN_FILTER_IDS.includes(value as PlanFilter) ? (value as PlanFilter) : 'today';
}

export function isToday(task: Task, todayKey: string): boolean {
	return planningBucket(task.plannedDate, task.dueDate, task.scheduledForToday === true, task.status).kind === 'today';
}

/**
 * Issue #991 S2/S3 — unified «Hoy» rule, the web leg of the one rule every
 * platform asserts against contracts/fixtures/task-planning-cases-991.json.
 * `plannedDate` is a day key (YYYY-MM-DD, local) exactly like `dueDate`;
 * day keys compare lexicographically. `scheduledForToday` is the legacy
 * pre-#991 boolean: it acts as a sync shim only where the new semantics
 * don't speak (no planned date, or a future one); a past planned date keeps
 * its S6 postponement.
 */
export type PlanningBucket =
	| { kind: 'today'; postponed: boolean }
	| { kind: 'upcoming' }
	| { kind: 'inbox' }
	| { kind: 'completed' };

export function planningBucket(
	plannedDate: string | null | undefined,
	dueDate: string | null | undefined,
	scheduledForToday: boolean,
	status: string,
	today: Date = new Date()
): PlanningBucket {
	if (status === 'completed') return { kind: 'completed' };
	const todayKey = localDateKey(today);
	const isFuture = (key: string) => key > todayKey;

	if (scheduledForToday && (!plannedDate || isFuture(plannedDate))) {
		return { kind: 'today', postponed: false };
	}
	if (plannedDate && !isFuture(plannedDate)) {
		return { kind: 'today', postponed: plannedDate !== todayKey };
	}
	if (dueDate && !isFuture(dueDate)) {
		return { kind: 'today', postponed: false };
	}
	return plannedDate || dueDate ? { kind: 'upcoming' } : { kind: 'inbox' };
}

export function filterTasks(tasks: Task[], filter: PlanFilter, today: Date = new Date()): Task[] {
	// Unified «Hoy» rule (issue #991 S2): every pill goes through one resolver.
	const active = tasks.filter((t) => t.status === 'active');
	const buckets = new Map(
		active.map((t) => [t.id, planningBucket(t.plannedDate, t.dueDate, t.scheduledForToday === true, t.status, today)])
	);
	switch (filter) {
		case 'all':
			return [...active].sort(byOrder);
		case 'today':
			return active.filter((t) => buckets.get(t.id)?.kind === 'today').sort(byOrder);
		case 'inbox':
			return active.filter((t) => buckets.get(t.id)?.kind === 'inbox').sort(byOrder);
		case 'upcoming':
			// #182: no one-week cap — sort by the first date (plan or due).
			return active
				.filter((t) => buckets.get(t.id)?.kind === 'upcoming')
				.sort(
					(a, b) =>
						(a.plannedDate ?? a.dueDate ?? '').localeCompare(b.plannedDate ?? b.dueDate ?? '') ||
						byOrder(a, b)
				);
		case 'completed':
			return tasks
				.filter((t) => t.status === 'completed')
				.sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''));
	}
}

/** Mac dueText (MacPlanView:355): Today / Tomorrow / Overdue / abbreviated
 * date. A task scheduled for today reads as Today even without a due date. */
export type DueKind = 'today' | 'tomorrow' | 'overdue' | 'date' | 'none';

export function dueInfo(
	task: Task,
	today: Date = new Date()
): { kind: DueKind; dateKey: string | null } {
	const todayKey = localDateKey(today);
	if (!task.dueDate) {
		return { kind: task.scheduledForToday === true ? 'today' : 'none', dateKey: null };
	}
	const tomorrow = new Date(today);
	tomorrow.setDate(tomorrow.getDate() + 1);
	if (task.dueDate === todayKey) return { kind: 'today', dateKey: task.dueDate };
	if (task.dueDate === localDateKey(tomorrow)) return { kind: 'tomorrow', dateKey: task.dueDate };
	// Mac dueText: Overdue requires !isCompleted — a completed task with a
	// past date shows the plain abbreviated date.
	if (task.dueDate < todayKey && task.status !== 'completed')
		return { kind: 'overdue', dateKey: task.dueDate };
	return { kind: 'date', dateKey: task.dueDate };
}

/** Abbreviated localized date for the Due column (Mac .abbreviated). */
export function formatDueShort(dateKey: string, locale: string): string {
	return new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short' }).format(
		new Date(`${dateKey}T12:00:00`)
	);
}

function byOrder(a: Task, b: Task): number {
	return a.order - b.order || a.createdAt.localeCompare(b.createdAt);
}

/** Group tasks by energy in native order (deep → shallow → admin). */
export function groupByEnergy(tasks: Task[]): { energy: TaskEnergy; tasks: Task[] }[] {
	return ENERGY_ORDER.map((energy) => ({
		energy,
		tasks: tasks.filter((t) => t.energy === energy)
	})).filter((g) => g.tasks.length > 0);
}

/** Defaults a quick-add inherits depending on the active pill. */
export function quickAddDefaults(filter: PlanFilter, today: Date = new Date()): Partial<Task> {
	// S5 (#991): quick add inherits a planned date — no invented deadlines.
	switch (filter) {
		case 'today':
			return { plannedDate: localDateKey(today), scheduledForToday: true };
		case 'upcoming': {
			const d = new Date(today);
			d.setDate(d.getDate() + 1);
			return { plannedDate: localDateKey(d), scheduledForToday: false };
		}
		default:
			return {};
	}
}

export function subtaskProgress(task: Task): { done: number; total: number } {
	const subs = task.subtasks ?? [];
	return { done: subs.filter((s) => s.isCompleted).length, total: subs.length };
}

/** Reorder within a visible subset: reassign dense order values. */
export function reorderSubset(subset: Task[], movedId: string, targetIndex: number): Map<string, number> {
	const others = subset.filter((t) => t.id !== movedId);
	const moved = subset.find((t) => t.id === movedId);
	if (!moved) return new Map();
	const next = [...others.slice(0, targetIndex), moved, ...others.slice(targetIndex)];
	const map = new Map<string, number>();
	next.forEach((t, i) => map.set(t.id, i));
	return map;
}
