import { describe, expect, it } from 'vitest';
import {
	RECURRENCE_PRESETS,
	advanceRecurring,
	localDateKey,
	nextOccurrence,
	parseRRule,
	presetByKey
} from '$lib/domain/tasks/recurrence';
import { suggestEnergy } from '$lib/domain/tasks/energy';
import {
	filterTasks,
	groupByEnergy,
	quickAddDefaults,
	reorderSubset,
	subtaskProgress
} from '$lib/domain/tasks/plan';
import type { Task } from '$lib/domain/entities/types';

const TODAY = new Date(2026, 10, 16); // Monday Nov 16 2026, local

function task(partial: Partial<Task>): Task {
	return {
		id: partial.id ?? 't',
		title: partial.title ?? 'task',
		status: partial.status ?? 'active',
		priority: partial.priority ?? 'none',
		energy: partial.energy ?? 'shallow',
		estimatedPomodoros: partial.estimatedPomodoros ?? 1,
		list: partial.list ?? 'inbox',
		order: partial.order ?? 0,
		createdAt: partial.createdAt ?? '2026-11-01T09:00:00',
		updatedAt: partial.updatedAt ?? '2026-11-01T09:00:00',
		...partial
	};
}

describe('recurrence.nextOccurrence', () => {
	it('parses the shipped presets', () => {
		for (const p of RECURRENCE_PRESETS) {
			expect(parseRRule(p.rrule)?.freq).toBeTruthy();
		}
		expect(presetByKey('daily')?.rrule).toBe('FREQ=DAILY');
	});

	it('daily advances one day', () => {
		expect(localDateKey(nextOccurrence('FREQ=DAILY', TODAY)!)).toBe('2026-11-17');
	});

	it('biweekly advances two weeks', () => {
		expect(localDateKey(nextOccurrence('FREQ=WEEKLY;INTERVAL=2', TODAY)!)).toBe('2026-11-30');
	});

	it('weekly lands on the same weekday next week', () => {
		expect(localDateKey(nextOccurrence('FREQ=WEEKLY', TODAY)!)).toBe('2026-11-23');
	});

	it('weekdays skips the weekend (Mon → Tue)', () => {
		expect(localDateKey(nextOccurrence('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', TODAY)!)).toBe(
			'2026-11-17'
		);
	});

	it('weekdays Friday → Monday', () => {
		const friday = new Date(2026, 10, 20); // Nov 20 2026 is a Friday
		expect(localDateKey(nextOccurrence('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR', friday)!)).toBe(
			'2026-11-23'
		);
	});

	it('monthly clamps overflow (Jan 31 → Feb 28)', () => {
		const jan31 = new Date(2026, 0, 31);
		expect(localDateKey(nextOccurrence('FREQ=MONTHLY', jan31)!)).toBe('2026-02-28');
	});

	it('returns null for unknown rules', () => {
		expect(nextOccurrence('FREQ=YEARLY', TODAY)).toBeNull();
	});
});

describe('advanceRecurring', () => {
	it('keeps the series alive and advances the due date', () => {
		const r = advanceRecurring('FREQ=DAILY', '2026-11-16', TODAY);
		expect(r?.nextDueDate).toBe('2026-11-17');
		expect(r?.lastCompletedAt).toBeTruthy();
	});

	it('uses today as base when no due date', () => {
		const r = advanceRecurring('FREQ=WEEKLY', null, TODAY);
		expect(r?.nextDueDate).toBe('2026-11-23');
	});
});

describe('suggestEnergy (cronobiología)', () => {
	it('follows the native windows', () => {
		expect(suggestEnergy(6)).toBe('deep');
		expect(suggestEnergy(9)).toBe('deep');
		expect(suggestEnergy(11)).toBe('shallow');
		expect(suggestEnergy(13)).toBe('admin');
		expect(suggestEnergy(15)).toBe('deep');
		expect(suggestEnergy(18)).toBe('shallow');
		expect(suggestEnergy(22)).toBe('admin');
		expect(suggestEnergy(3)).toBe('admin');
	});
});

describe('filterTasks', () => {
	it('all: every active task in stable order (Mac sidebar "Todas")', () => {
		const tasks = [
			task({ id: 'b', order: 1, scheduledForToday: true }),
			task({ id: 'a', order: 0, dueDate: '2026-11-20' }),
			task({ id: 'c', order: 2 }),
			task({ id: 'done', status: 'completed', scheduledForToday: true })
		];
		const ids = filterTasks(tasks, 'all', TODAY).map((t) => t.id);
		expect(ids).toEqual(['a', 'b', 'c']);
	});

	it('today: scheduled or due today', () => {
		const tasks = [
			task({ id: 'a', scheduledForToday: true }),
			task({ id: 'b', dueDate: localDateKey(TODAY) }),
			task({ id: 'c' }),
			task({ id: 'd', dueDate: '2026-11-20' }),
			task({ id: 'e', status: 'completed', scheduledForToday: true })
		];
		const ids = filterTasks(tasks, 'today', TODAY).map((t) => t.id);
		expect(ids).toEqual(['a', 'b']);
	});

	it('inbox: no due date and not scheduled', () => {
		const tasks = [task({ id: 'a', scheduledForToday: true }), task({ id: 'c' })];
		expect(filterTasks(tasks, 'inbox', TODAY).map((t) => t.id)).toEqual(['c']);
	});

	it('upcoming: future due dates sorted', () => {
		const tasks = [
			task({ id: 'd2', dueDate: '2026-11-20' }),
			task({ id: 'd1', dueDate: '2026-11-18' }),
			task({ id: 'todayTask', dueDate: localDateKey(TODAY) })
		];
		expect(filterTasks(tasks, 'upcoming', TODAY).map((t) => t.id)).toEqual(['d1', 'd2']);
	});

	it('completed: newest first', () => {
		const tasks = [
			task({ id: 'old', status: 'completed', createdAt: '2026-11-01T09:00:00' }),
			task({ id: 'new', status: 'completed', createdAt: '2026-11-01T09:00:00' })
		];
		tasks[0].completedAt = '2026-11-10T09:00:00';
		tasks[1].completedAt = '2026-11-15T09:00:00';
		expect(filterTasks(tasks, 'completed', TODAY).map((t) => t.id)).toEqual(['new', 'old']);
	});
});

describe('groupByEnergy', () => {
	it('groups in native order and drops empties', () => {
		const tasks = [
			task({ id: 'a', energy: 'admin' }),
			task({ id: 'b', energy: 'deep' }),
			task({ id: 'c', energy: 'deep' })
		];
		const groups = groupByEnergy(tasks);
		expect(groups.map((g) => g.energy)).toEqual(['deep', 'admin']);
		expect(groups[0].tasks).toHaveLength(2);
	});
});

describe('quickAddDefaults', () => {
	it('today marks scheduled; upcoming seeds tomorrow', () => {
		expect(quickAddDefaults('today', TODAY).scheduledForToday).toBe(true);
		expect(quickAddDefaults('upcoming', TODAY).dueDate).toBe('2026-11-17');
		expect(quickAddDefaults('inbox', TODAY)).toEqual({});
	});
});

describe('subtasks + reorder', () => {
	it('computes subtask progress', () => {
		const t = task({
			subtasks: [
				{ id: 's1', title: 'a', isCompleted: true, sortOrder: 0, createdAt: '' },
				{ id: 's2', title: 'b', isCompleted: false, sortOrder: 1, createdAt: '' }
			]
		});
		expect(subtaskProgress(t)).toEqual({ done: 1, total: 2 });
	});

	it('reorders within the visible subset with dense orders', () => {
		const subset = [task({ id: 'a', order: 0 }), task({ id: 'b', order: 1 }), task({ id: 'c', order: 2 })];
		const map = reorderSubset(subset, 'a', 2);
		expect(map.get('b')).toBe(0);
		expect(map.get('c')).toBe(1);
		expect(map.get('a')).toBe(2);
	});
});
