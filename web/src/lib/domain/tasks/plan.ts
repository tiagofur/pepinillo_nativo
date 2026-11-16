/**
 * Plan filters and grouping — pure helpers behind the Plan page.
 * Pills mirror the native TaskFilter{Today, Inbox, Upcoming, Completed}.
 */

import type { Task, TaskEnergy } from '$lib/domain/entities/types';
import { ENERGY_ORDER } from './energy';
import { localDateKey } from './recurrence';

export type PlanFilter = 'today' | 'inbox' | 'upcoming' | 'completed';

export const PLAN_FILTERS: readonly PlanFilter[] = ['today', 'inbox', 'upcoming', 'completed'] as const;

export function isToday(task: Task, todayKey: string): boolean {
	return task.scheduledForToday === true || task.dueDate === todayKey;
}

export function filterTasks(tasks: Task[], filter: PlanFilter, today: Date = new Date()): Task[] {
	const todayKey = localDateKey(today);
	const active = tasks.filter((t) => t.status === 'active');
	switch (filter) {
		case 'today':
			return active.filter((t) => isToday(t, todayKey)).sort(byOrder);
		case 'inbox':
			return active
				.filter((t) => !isToday(t, todayKey) && !t.dueDate)
				.sort(byOrder);
		case 'upcoming':
			return active
				.filter((t) => t.dueDate && t.dueDate !== todayKey)
				.sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? '') || byOrder(a, b));
		case 'completed':
			return tasks
				.filter((t) => t.status === 'completed')
				.sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''));
	}
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
	switch (filter) {
		case 'today':
			return { scheduledForToday: true };
		case 'upcoming': {
			const d = new Date(today);
			d.setDate(d.getDate() + 1);
			return { dueDate: localDateKey(d) };
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
