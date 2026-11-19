<script lang="ts">
	import { onMount } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Sheet from '$lib/design/Sheet.svelte';
	import { listSessions } from '$lib/data/local/idb';
	import { RECURRENCE_PRESETS, type RecurrencePresetKey } from '$lib/domain/tasks/recurrence';
	import type { Task, TaskEnergy, TaskPriority } from '$lib/domain/entities/types';
	import { suggestEnergy } from '$lib/domain/tasks/energy';
	import Icon from '$lib/design/Icon.svelte';

	let {
		task,
		onclose
	}: { task: Task | null; onclose: () => void } = $props();

	// One inspector instance in the DOM: side panel on desktop, sheet on mobile.
	let isDesktop = $state(false);

	onMount(() => {
		const mq = window.matchMedia('(min-width: 1024px)');
		isDesktop = mq.matches;
		const onChange = (e: MediaQueryListEvent) => {
			isDesktop = e.matches;
		};
		mq.addEventListener('change', onChange);
		return () => mq.removeEventListener('change', onChange);
	});

	// Mac order: high → none (MacTaskInspectorView:173)
	const PRIORITIES: { id: TaskPriority; key: MessageKey }[] = [
		{ id: 'high', key: 'plan.priority.high' },
		{ id: 'medium', key: 'plan.priority.medium' },
		{ id: 'low', key: 'plan.priority.low' },
		{ id: 'none', key: 'plan.priority.none' }
	];

	const ENERGIES: { id: TaskEnergy; key: MessageKey }[] = [
		{ id: 'deep', key: 'plan.energy.deep' },
		{ id: 'shallow', key: 'plan.energy.shallow' },
		{ id: 'admin', key: 'plan.energy.admin' }
	];

	let subInput = $state('');
	let confirmDelete = $state(false);
	let analytics = $state<{ sessions: number; seconds: number } | null>(null);
	let draftTitle = $state('');

	// Load per-task analytics when the inspected task changes.
	let analyticsFor = $state<string | null>(null);
	$effect(() => {
		const id = task?.id ?? null;
		draftTitle = task?.title ?? '';
		confirmDelete = false;
		if (!id || analyticsFor === id) return;
		analyticsFor = id;
		analytics = null;
		void listSessions().then((sessions) => {
			const mine = sessions.filter((s) => s.taskId === id && (s.phase ?? 'work') === 'work');
			analytics = {
				sessions: mine.filter((s) => s.status === 'completed').length,
				seconds: Math.round(mine.reduce((acc, s) => acc + s.elapsedMs / 1000, 0))
			};
		});
	});

	function fmt(seconds: number): string {
		const m = Math.floor(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	async function addSubtask(): Promise<void> {
		if (!task || !subInput.trim()) return;
		await plan.addSubtask(task.id, subInput);
		subInput = '';
	}

	function setPomodoros(delta: number): void {
		if (!task) return;
		const next = Math.max(1, Math.min(8, task.estimatedPomodoros + delta));
		void plan.updateTask(task.id, { estimatedPomodoros: next });
	}

	function suggestNow(): void {
		if (!task) return;
		void plan.updateTask(task.id, { energy: suggestEnergy(new Date().getHours()) });
	}

	async function remove(): Promise<void> {
		if (!task) return;
		await plan.deleteTask(task.id);
		onclose();
	}

	async function focusTask(): Promise<void> {
		if (!task) return;
		plan.focusOn(task);
		// Mac inspector footer parity: starts the session, not just links it.
		if (focus.idle && !focus.waiting) focus.start();
		onclose();
		const { goto } = await import('$app/navigation');
		await goto('/focus');
	}
</script>

<!-- Desktop: side panel -->
{#if isDesktop}
	<aside class="inspector card" class:open={task !== null}>
		{#if task}
			{@render Body()}
		{/if}
	</aside>
{:else}
	<!-- Mobile: sheet -->
	<Sheet open={task !== null} onclose={onclose} title={t('plan.inspector')}>
		{#if task}
			{@render Body()}
		{/if}
	</Sheet>
{/if}

{#snippet Body()}
	<div class="head">
		<button
			class="check pressable"
			aria-label={t('plan.complete')}
			aria-pressed={task?.status === 'completed'}
			onclick={() => task && plan.toggleComplete(task.id)}
		></button>
		<input
			class="title-input field"
			value={draftTitle}
			onchange={(e) => task && plan.updateTask(task.id, { title: e.currentTarget.value })}
			aria-label={t('plan.title')}
		/>
	</div>

	<div class="chips">
		{#each PRIORITIES as p (p.id)}
			<button
				class="chip pressable"
				aria-pressed={task?.priority === p.id}
				class:is-active={task?.priority === p.id}
				onclick={() => task && plan.updateTask(task.id, { priority: p.id })}
			>
				{t(p.key)}
			</button>
		{/each}
	</div>

	<div class="chips">
		{#each ENERGIES as en (en.id)}
			<button
				class="chip pressable"
				aria-pressed={task?.energy === en.id}
				class:is-active={task?.energy === en.id}
				onclick={() => task && plan.updateTask(task.id, { energy: en.id })}
			>
				{t(en.key)}
			</button>
		{/each}
		<button class="chip pressable hint-chip" onclick={suggestNow} title={t('plan.energySuggest')}>
			✨ {t('plan.energySuggest')}
		</button>
	</div>

	<div class="row-block">
		<span class="label">🍅 {t('plan.estPomos')}</span>
		<div class="stepper">
			<button class="btn btn-ghost btn-icon pressable" onclick={() => setPomodoros(-1)}>−</button>
			<span class="nums">{task?.estimatedPomodoros ?? 1}</span>
			<button class="btn btn-ghost btn-icon pressable" onclick={() => setPomodoros(1)}>+</button>
		</div>
	</div>

	<label class="row-block">
		<span class="label">📅 {t('plan.dueDate')}</span>
		<input
			type="date"
			class="field"
			value={task?.dueDate ?? ''}
			onchange={(e) => task && plan.updateTask(task.id, { dueDate: e.currentTarget.value || null })}
		/>
	</label>

	<label class="switch">
		<input
			type="checkbox"
			checked={task?.scheduledForToday === true}
			onchange={(e) => task && plan.updateTask(task.id, { scheduledForToday: e.currentTarget.checked })}
		/>
		<span>⭐ {t('plan.focusToday')}</span>
	</label>

	<div class="row-block">
		<span class="label">🔁 {t('plan.recurrence')}</span>
		<div class="chips">
			{#each RECURRENCE_PRESETS as p (p.key)}
				{@const active = task?.recurrenceRule === p.rrule}
				<button
					class="chip pressable"
					class:is-active={active}
					class:is-locked={!plan.canUseRecurrence() && !active}
					disabled={!plan.canUseRecurrence() && !active}
					onclick={() => task && plan.setRecurrence(task.id, active ? null : (p.key as RecurrencePresetKey))}
					title={!plan.canUseRecurrence() && !active ? t('common.proLocked') : ''}
				>
					{t(`plan.recurrence.${p.key}` as MessageKey)}
				</button>
			{/each}
		</div>
	</div>

	<div class="row-block">
		<span class="label">🗒️ {t('plan.notes')}</span>
		<textarea
			class="field"
			rows="2"
			placeholder={t('plan.notesPlaceholder')}
			value={task?.notes ?? ''}
			onchange={(e) => task && plan.updateTask(task.id, { notes: e.currentTarget.value })}
		></textarea>
	</div>

	<div class="row-block">
		<span class="label">☑️ {t('plan.subtasks')}</span>
		<ul class="subs">
			{#each task?.subtasks ?? [] as s (s.id)}
				<li class="sub">
					<button
						class="sub-check pressable"
						aria-pressed={s.isCompleted}
						aria-label={t('plan.complete')}
						onclick={() => task && plan.toggleSubtask(task.id, s.id)}
					></button>
					<span class="sub-title" class:done={s.isCompleted}>{s.title}</span>
					<button
						class="sub-del pressable"
						aria-label={t('plan.subtaskDelete')}
						onclick={() => task && plan.deleteSubtask(task.id, s.id)}
					>✕</button>
				</li>
			{/each}
		</ul>
		{#if plan.canUseSubtasks()}
			<input
				class="field"
				placeholder={t('plan.subtaskAdd')}
				bind:value={subInput}
				onkeydown={(e) => e.key === 'Enter' && addSubtask()}
			/>
		{:else}
			<p class="gate">🔒 {t('plan.subtasksGate')}</p>
		{/if}
	</div>

	{#if analytics}
		<div class="row-block analytics">
			<span class="label">📊 {t('plan.analytics')}</span>
			<span class="nums">
				{t('plan.analytics.sessions', { count: analytics.sessions })} ·
				{t('plan.analytics.focus', { time: fmt(analytics.seconds) })}
			</span>
		</div>
	{/if}

	<div class="actions">
		<button class="btn btn-primary pressable focus-cta" onclick={focusTask}>
			<Icon name="play" size={15} />
			{t('plan.focusSession')}
		</button>
		{#if confirmDelete}
			<button class="btn pressable danger-confirm" onclick={remove}>
				{t('plan.deleteConfirm')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => (confirmDelete = false)}>
				{t('journal.skip')}
			</button>
		{:else}
			<button class="btn btn-ghost pressable danger" onclick={() => (confirmDelete = true)}>
				🗑 {t('plan.delete')}
			</button>
		{/if}
	</div>
{/snippet}

<style>
	.inspector {
		display: none;
	}

	@media (min-width: 1024px) {
		.inspector {
			display: flex;
			position: sticky;
			top: var(--space-6);
			flex-direction: column;
			gap: var(--space-4);
			padding: var(--space-5);
			/* Lives inside .plan-scroll (≈100dvh − toolbar/gaps/bar) on desktop */
			max-height: calc(100dvh - 200px);
			overflow-y: auto;
			overflow-y: auto;
			visibility: hidden;
			opacity: 0;
			transition: opacity var(--dur-base) var(--ease-out-quint);
		}

		.inspector.open {
			visibility: visible;
			opacity: 1;
		}

		:global(.inspector-grid) {
			display: grid;
			grid-template-columns: minmax(0, 1fr) 360px;
			gap: var(--space-6);
			align-items: start;
		}

		/* Closed inspector: the table spans the full width (Mac behavior) */
		:global(.inspector-grid:not(.with-inspector)) {
			grid-template-columns: minmax(0, 1fr);
		}
	}

	.head {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.check {
		flex: none;
		width: 22px;
		height: 22px;
		border-radius: 50%;
		border: 2px solid var(--border-strong);
		background: transparent;
		cursor: pointer;
	}

	.check[aria-pressed='true'] {
		background: var(--brand);
		border-color: var(--brand);
	}

	.title-input {
		font-weight: 650;
	}

	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.hint-chip {
		border-style: dashed;
	}

	.row-block {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.label {
		color: var(--muted);
		font-size: var(--text-sm);
		font-weight: 600;
	}

	.stepper {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		font-weight: 650;
	}

	.switch {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: var(--touch-target);
		color: var(--ink-secondary);
		cursor: pointer;
	}

	.switch input {
		width: 20px;
		height: 20px;
		accent-color: var(--brand);
	}

	.subs {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.sub {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 40px;
	}

	.sub-check {
		width: 18px;
		height: 18px;
		border-radius: 6px;
		border: 2px solid var(--border-strong);
		background: transparent;
		cursor: pointer;
		flex: none;
	}

	.sub-check[aria-pressed='true'] {
		background: var(--brand);
		border-color: var(--brand);
	}

	.sub-title {
		flex: 1;
		font-size: var(--text-sm);
	}

	.sub-title.done {
		text-decoration: line-through;
		color: var(--muted);
	}

	.sub-del {
		background: none;
		border: none;
		color: var(--faint);
		cursor: pointer;
		min-width: 32px;
		min-height: 32px;
	}

	.gate {
		color: var(--muted);
		font-size: var(--text-xs);
		background: var(--surface-alt);
		border-radius: var(--radius-md);
		padding: var(--space-2) var(--space-3);
	}

	.analytics {
		background: var(--surface-alt);
		border-radius: var(--radius-md);
		padding: var(--space-3);
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	/* Mac footer: the prominent Start Focus Session spans the full width */
	.focus-cta {
		flex: 1 0 100%;
		justify-content: center;
	}

	.danger {
		color: var(--mode-pomodoro);
	}

	.danger-confirm {
		background: var(--mode-pomodoro-soft);
		color: var(--mode-pomodoro);
		border: 1px solid transparent;
		font-weight: 650;
	}
</style>
