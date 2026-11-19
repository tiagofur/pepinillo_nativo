/**
 * PlanStore — task CRUD over IndexedDB with native-parity behavior:
 * filters, drag reorder (dense orders inside the visible subset),
 * recurring-series advancement on completion, subtasks (Pepinillo+),
 * free-tier active cap (3).
 */
import { browser } from '$app/environment';
import {
	listAllTasks,
	listActiveTasks,
	removeTask,
	saveAllTasks,
	upsertTask
} from '$lib/data/local/idb';
import { canCreateActiveTask, canUseRecurrence, canUseSubtasks } from '$lib/domain/gates/freeLimits';
import {
	advanceRecurring,
	localDateKey,
	presetByKey,
	type RecurrencePresetKey
} from '$lib/domain/tasks/recurrence';
import { filterTasks, reorderSubset, type PlanFilter } from '$lib/domain/tasks/plan';
import { app } from '$lib/stores/app.svelte';
import { focus } from '$lib/stores/focus.svelte';
import { toast } from '$lib/stores/toast.svelte';
import { t as translate } from '$lib/i18n/i18n.svelte';
import type { SubTask, Task } from '$lib/domain/entities/types';

/** Undo snapshot for one reversible operation (MacPlanView parity). */
interface UndoSnapshot {
	label: string;
	apply: () => Promise<void>;
}

function uid(): string {
	return `t-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
}

/** Local writes notify the auth store's debounced push (S3 #942) without a
 * direct import (auth pulls plan on sync — importing it back is circular). */
function notifyMutation(): void {
	if (typeof window !== 'undefined') window.dispatchEvent(new Event('pepinillo:local-mutation'));
}

class PlanStore {
	tasks = $state<Task[]>([]);
	filter = $state<PlanFilter>('today');
	capNotice = $state(false);
	loaded = $state(false);

	private nextOrder = 0;

	async init(): Promise<void> {
		if (!browser) return;
		await app.init();
		await this.reload();
		this.loaded = true;
	}

	private async reload(): Promise<void> {
		this.tasks = await listAllTasks();
		const active = this.tasks.filter((t) => t.status === 'active');
		this.nextOrder = active.length > 0 ? Math.max(...active.map((t) => t.order)) + 1 : 0;
	}

	visible = $derived.by(() => filterTasks(this.tasks, this.filter));

	activeCount = $derived(this.tasks.filter((t) => t.status === 'active').length);

	freeCapReached = $derived(!canCreateActiveTask(this.activeCount, this.tier));

	private get tier() {
		return app.tier;
	}

	// ---------- CRUD ----------

	async addTask(title: string, defaults: Partial<Task> = {}): Promise<Task | null> {
		const trimmed = title.trim();
		if (!trimmed) return null;
		if (this.freeCapReached) {
			this.capNotice = true;
			return null;
		}
		const now = new Date().toISOString();
		const task: Task = {
			id: uid(),
			title: trimmed,
			status: 'active',
			priority: 'none',
			energy: 'shallow',
			estimatedPomodoros: 1,
			list: 'inbox',
			order: this.nextOrder++,
			createdAt: now,
			updatedAt: now,
			completedPomodoros: 0,
			...defaults
		};
		this.tasks = [...this.tasks, task];
		notifyMutation();
		await upsertTask(task);
		return task;
	}

	async updateTask(id: string, patch: Partial<Task>): Promise<void> {
		const idx = this.tasks.findIndex((t) => t.id === id);
		if (idx === -1) return;
		const updated: Task = $state.snapshot({
			...this.tasks[idx],
			...patch,
			updatedAt: new Date().toISOString()
		});
		this.tasks = this.tasks.map((t) => (t.id === id ? updated : t));
		notifyMutation();
		await upsertTask(updated);
	}

	/** Toggle completion; recurring series advance instead of ending. */
	async toggleComplete(id: string): Promise<void> {
		const task = this.tasks.find((t) => t.id === id);
		if (!task) return;
		if (task.status === 'active') {
			if (task.recurrenceRule) {
				const adv = advanceRecurring(task.recurrenceRule, task.dueDate ?? null);
				await this.updateTask(id, {
					lastCompletedAt: adv?.lastCompletedAt ?? new Date().toISOString(),
					dueDate: adv?.nextDueDate ?? task.dueDate,
					completedAt: null
				});
				return;
			}
			await this.updateTask(id, { status: 'completed', completedAt: new Date().toISOString() });
			this.offerUndo({
				label: `'${task.title}' completed`,
				apply: async () => {
					await this.updateTask(id, { status: 'active', completedAt: null });
				}
			});
		} else {
			await this.updateTask(id, { status: 'active', completedAt: null });
		}
	}

	async deleteTask(id: string): Promise<void> {
		const snapshot = this.tasks.find((t) => t.id === id);
		this.tasks = this.tasks.filter((t) => t.id !== id);
		if (focus.activeTask?.id === id) focus.setActiveTask(null);
		await removeTask(id);
		if (snapshot) {
			this.offerUndo({
				label: translate('plan.undo.deleted', { title: snapshot.title }),
				apply: async () => {
					notifyMutation();
		await upsertTask($state.snapshot(snapshot));
					await this.reload();
				}
			});
		}
	}

	/** MacPlanView parity: snackbar with UNDO (5 s) after destructive actions. */
	private offerUndo(snapshot: UndoSnapshot): void {
		toast.action(snapshot.label, translate('toast.undo'), () => void snapshot.apply());
	}

	/** Dense reorder inside the currently visible subset. */
	async reorder(movedId: string, targetIndex: number): Promise<void> {
		const subset = filterTasks(this.tasks, this.filter);
		if (subset.length < 2) return;
		const map = reorderSubset(subset, movedId, Math.max(0, Math.min(subset.length - 1, targetIndex)));
		const changed: Task[] = [];
		this.tasks = this.tasks.map((t) => {
			const order = map.get(t.id);
			if (order === undefined || order === t.order) return t;
			const updated = { ...t, order, updatedAt: new Date().toISOString() };
			changed.push($state.snapshot(updated));
			return updated;
		});
		notifyMutation();
		await saveAllTasks(changed);
	}

	// ---------- Subtasks (Pepinillo+) ----------

	canUseSubtasks(): boolean {
		return canUseSubtasks(app.tier);
	}

	async addSubtask(taskId: string, title: string): Promise<void> {
		const task = this.tasks.find((t) => t.id === taskId);
		if (!task || !this.canUseSubtasks()) return;
		const subs: SubTask[] = [
			...(task.subtasks ?? []),
			{
				id: uid(),
				title: title.trim(),
				isCompleted: false,
				sortOrder: (task.subtasks ?? []).length,
				createdAt: new Date().toISOString()
			}
		];
		await this.updateTask(taskId, { subtasks: subs });
	}

	async toggleSubtask(taskId: string, subId: string): Promise<void> {
		const task = this.tasks.find((t) => t.id === taskId);
		if (!task) return;
		await this.updateTask(taskId, {
			subtasks: (task.subtasks ?? []).map((s) =>
				s.id === subId ? { ...s, isCompleted: !s.isCompleted } : s
			)
		});
	}

	async deleteSubtask(taskId: string, subId: string): Promise<void> {
		const task = this.tasks.find((t) => t.id === taskId);
		if (!task) return;
		await this.updateTask(taskId, {
			subtasks: (task.subtasks ?? []).filter((s) => s.id !== subId)
		});
	}

	// ---------- Recurrence ----------

	canUseRecurrence(): boolean {
		return canUseRecurrence(app.tier);
	}

	async setRecurrence(taskId: string, preset: RecurrencePresetKey | null): Promise<void> {
		if (preset && !this.canUseRecurrence()) return;
		const rule = preset ? (presetByKey(preset)?.rrule ?? null) : null;
		await this.updateTask(taskId, { recurrenceRule: rule });
	}

	// ---------- Focus bridge ----------

	/** Called by the focus controller when a linked work session completes. */
	async bumpPomodoro(taskId: string | null): Promise<void> {
		if (!taskId) return;
		const task = this.tasks.find((t) => t.id === taskId);
		if (!task) return;
		await this.updateTask(taskId, {
			completedPomodoros: (task.completedPomodoros ?? 0) + 1
		});
	}

	focusOn(task: Task): void {
		focus.setActiveTask(task);
	}

	setFilter(filter: PlanFilter): void {
		this.filter = filter;
	}

	/** Refresh active list for pickers (IDB is source of truth across tabs). */
	async activeTasks(): Promise<Task[]> {
		return listActiveTasks();
	}

	scheduledTodayCount(today: Date = new Date()): number {
		return filterTasks(this.tasks, 'today', today).length;
	}
}

export const plan = new PlanStore();
