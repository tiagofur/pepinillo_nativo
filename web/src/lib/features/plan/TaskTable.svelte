<script lang="ts">
	/**
	 * Mac-style tasks table (MacPlanView parity) for ≥1024px:
	 * columns ✓ / Title / Priority / Energy / 🍅 / Due, inline title
	 * editing, row selection for the inspector. Hidden below 1024px
	 * (the energy-grouped list takes over).
	 */
	import { tick } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { subtaskProgress } from '$lib/domain/tasks/plan';
	import { localDateKey } from '$lib/domain/tasks/recurrence';
	import type { Task } from '$lib/domain/entities/types';

	let {
		tasks,
		selectedId,
		onselect,
		ontoggle,
		onfocus
	}: {
		tasks: Task[];
		selectedId: string | null;
		onselect: (id: string) => void;
		ontoggle: (id: string) => void;
		onfocus: (task: Task) => void;
	} = $props();

	const PRIORITY_COLOR: Record<string, string> = {
		none: 'transparent',
		low: '#1e88e5',
		medium: '#fb8c00',
		high: '#e53935'
	};

	const ENERGY_COLOR: Record<string, string> = {
		deep: 'var(--brand)',
		shallow: 'var(--mode-flowtime)',
		admin: 'var(--streak)'
	};

	const ENERGY_KEYS: Record<string, MessageKey> = {
		deep: 'plan.energy.deep',
		shallow: 'plan.energy.shallow',
		admin: 'plan.energy.admin'
	};

	let editingId = $state<string | null>(null);
	let draftTitle = $state('');
	let editEl = $state<HTMLInputElement | null>(null);

	function startEdit(task: Task): void {
		editingId = task.id;
		draftTitle = task.title;
		// Focus after the input mounts (avoids autofocus).
		tick().then(() => editEl?.focus());
	}

	function commitEdit(task: Task): void {
		if (editingId === task.id && draftTitle.trim() && draftTitle !== task.title) {
			void plan.updateTask(task.id, { title: draftTitle.trim() });
		}
		editingId = null;
	}

	function todayKey(): string {
		return localDateKey(new Date());
	}
</script>

<div class="task-table card" role="table" aria-label={t('plan.title')}>
	<div class="thead" role="row">
		<span class="col-check" aria-hidden="true"></span>
		<span class="col-title" role="columnheader">{t('plan.title')}</span>
		<span class="col-pri" role="columnheader">{t('plan.priority')}</span>
		<span class="col-energy" role="columnheader">{t('plan.energy')}</span>
		<span class="col-pomo" role="columnheader">🍅</span>
		<span class="col-due" role="columnheader">{t('plan.dueDate')}</span>
		<span class="col-actions" aria-hidden="true"></span>
	</div>

	{#each tasks as task (task.id)}
		<div
			class="trow"
			class:selected={selectedId === task.id}
			role="row"
			onclick={() => onselect(task.id)}
			onkeydown={(e) => e.key === 'Enter' && onselect(task.id)}
			tabindex="0"
		>
			<span class="col-check" role="cell">
				<button
					class="check pressable"
					aria-label={t('plan.complete')}
					aria-pressed={task.status === 'completed'}
					onclick={(e) => {
						e.stopPropagation();
						ontoggle(task.id);
					}}
				></button>
			</span>
			<span class="col-title" role="cell">
				{#if editingId === task.id}
					<input
						class="title-edit"
						bind:this={editEl}
						value={draftTitle}
						onblur={() => commitEdit(task)}
						onkeydown={(e) => {
							if (e.key === 'Enter') commitEdit(task);
							if (e.key === 'Escape') editingId = null;
						}}
					/>
				{:else}
					<button
						class="title-btn"
						ondblclick={(e) => {
							e.stopPropagation();
							startEdit(task);
						}}
						aria-label={task.title}
					>
						{task.title}
					</button>
				{/if}
				{#if (task.subtasks?.length ?? 0) > 0}
					<span class="mini nums">{subtaskProgress(task).done}/{subtaskProgress(task).total}</span>
				{/if}
				{#if task.recurrenceRule}
					<span class="mini">🔁</span>
				{/if}
			</span>
			<span class="col-pri" role="cell">
				<span class="dot" title={task.priority} style="background: {PRIORITY_COLOR[task.priority]}"></span>
			</span>
			<span class="col-energy" role="cell">
				<span class="energy-chip" style="color: {ENERGY_COLOR[task.energy]}; background: color-mix(in srgb, {ENERGY_COLOR[task.energy]} 10%, transparent)">
					{t(ENERGY_KEYS[task.energy])}
				</span>
			</span>
			<span class="col-pomo nums" role="cell">🍅 {task.completedPomodoros ?? 0}/{task.estimatedPomodoros}</span>
			<span class="col-due nums" role="cell" class:overdue={!!task.dueDate && task.dueDate < todayKey()}>
				{task.dueDate ?? '—'}
			</span>
			<span class="col-actions" role="cell">
				<button
					class="row-focus pressable"
					title={t('plan.focusTask')}
					onclick={(e) => {
						e.stopPropagation();
						onfocus(task);
					}}
				>
					▶
				</button>
			</span>
		</div>
	{/each}
</div>

<style>
	.task-table {
		overflow: hidden;
	}

	.thead,
	.trow {
		display: grid;
		grid-template-columns: 44px minmax(0, 1fr) 56px 92px 72px 92px 44px;
		align-items: center;
		gap: var(--space-2);
		padding: 0 var(--space-4);
	}

	.thead {
		min-height: 40px;
		border-bottom: 1px solid var(--hairline);
		font-size: var(--text-2xs);
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--muted);
	}

	.trow {
		min-height: 48px;
		border-bottom: 1px solid var(--hairline);
		cursor: pointer;
		transition: background-color var(--dur-fast) var(--ease-out-quint);
	}

	.trow:last-child {
		border-bottom: none;
	}

	.trow:hover {
		background: var(--surface-alt);
	}

	.trow.selected {
		background: var(--brand-softer);
	}

	.col-title {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-width: 0;
	}

	.title-btn {
		flex: 1;
		min-width: 0;
		background: none;
		border: none;
		padding: 0;
		font-weight: 550;
		color: var(--ink);
		cursor: text;
		text-align: start;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		min-height: 32px;
	}

	.title-edit {
		width: 100%;
		min-height: 32px;
		padding: 0 var(--space-2);
	}

	.mini {
		font-size: var(--text-2xs);
		color: var(--faint);
	}

	.check {
		width: 20px;
		height: 20px;
		border-radius: 50%;
		border: 2px solid var(--border-strong);
		background: transparent;
		cursor: pointer;
	}

	.check[aria-pressed='true'] {
		background: var(--brand);
		border-color: var(--brand);
	}

	.dot {
		display: inline-block;
		width: 8px;
		height: 8px;
		border-radius: 50%;
	}

	.energy-chip {
		font-size: var(--text-2xs);
		font-weight: 650;
		border-radius: var(--radius-pill);
		padding: 2px 8px;
		white-space: nowrap;
	}

	.col-pomo,
	.col-due {
		font-size: var(--text-xs);
		color: var(--muted);
	}

	.col-due.overdue {
		color: var(--mode-pomodoro);
		font-weight: 650;
	}

	.row-focus {
		background: none;
		border: 1px solid var(--border);
		border-radius: var(--radius-pill);
		color: var(--brand);
		font-size: 10px;
		cursor: pointer;
		min-width: 32px;
		min-height: 32px;
	}

	.row-focus:hover {
		background: var(--brand-soft);
		border-color: transparent;
	}
</style>
