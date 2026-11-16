<script lang="ts">
	import { onMount } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import TaskRow from '$lib/features/plan/TaskRow.svelte';
	import TaskTable from '$lib/features/plan/TaskTable.svelte';
	import TaskInspector from '$lib/features/plan/TaskInspector.svelte';
	import Segmented from '$lib/design/Segmented.svelte';
	import { groupByEnergy, PLAN_FILTERS, quickAddDefaults, type PlanFilter } from '$lib/domain/tasks/plan';
	import { suggestEnergy } from '$lib/domain/tasks/energy';
	import type { Task } from '$lib/domain/entities/types';

	onMount(() => {
		void plan.init();
	});

	const FILTER_KEYS: { id: PlanFilter; key: MessageKey }[] = [
		{ id: 'today', key: 'plan.filter.today' },
		{ id: 'inbox', key: 'plan.filter.inbox' },
		{ id: 'upcoming', key: 'plan.filter.upcoming' },
		{ id: 'completed', key: 'plan.filter.completed' }
	];

	const EMPTY_KEYS: Record<PlanFilter, MessageKey> = {
		today: 'plan.empty.today',
		inbox: 'plan.empty.inbox',
		upcoming: 'plan.empty.upcoming',
		completed: 'plan.empty.completed'
	};

	let quickValue = $state('');
	let selectedId = $state<string | null>(null);
	let dragId = $state<string | null>(null);
	let showCapNotice = $state(false);

	let selectedTask = $derived(plan.tasks.find((x) => x.id === selectedId) ?? null);
	let suggestion = $derived(suggestEnergy(new Date().getHours()));

	async function quickAdd(): Promise<void> {
		const defaults = quickAddDefaults(plan.filter);
		const created = await plan.addTask(quickValue, defaults);
		quickValue = '';
		if (!created) showCapNotice = true;
	}

	function selectTask(id: string | null): void {
		selectedId = id;
	}

	function focusTask(task: Task): void {
		plan.focusOn(task);
		gotoFocus();
	}

	async function gotoFocus(): Promise<void> {
		const { goto } = await import('$app/navigation');
		await goto('/focus');
	}

	// ---- Drag reorder (HTML5 drag: mouse + touch via draggable) ----
	function ondragstart(id: string): () => void {
		return () => {
			dragId = id;
		};
	}

	function dragOverHandler(): (ev: DragEvent) => void {
		return (ev) => {
			ev.preventDefault();
		};
	}

	async function ondrop(targetId: string): Promise<void> {
		const subset = plan.visible;
		const targetIndex = subset.findIndex((x) => x.id === targetId);
		if (dragId && targetIndex >= 0) {
			await plan.reorder(dragId, targetIndex);
		}
		dragId = null;
	}
</script>

<svelte:head>
	<title>{t('plan.title')} · Pepinillo</title>
</svelte:head>

<section class="plan rise-in">
	<header class="toolbar">
		<Segmented
			options={FILTER_KEYS.map((f) => ({ id: f.id, label: t(f.key) }))}
			value={plan.filter}
			onchange={(id) => plan.setFilter(id as PlanFilter)}
		/>
		<button
			class="chip pressable qc-open"
			onclick={() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true }))}
			title={t('quickCapture.hint')}
		>
			⚡ <span class="qc-label">{t('quickCapture.title')}</span>
		</button>
	</header>

	<form
		class="quickadd"
		onsubmit={(e) => {
			e.preventDefault();
			void quickAdd();
		}}
	>
		<input
			class="field"
			placeholder={t('plan.quickPlaceholder')}
			bind:value={quickValue}
			aria-label={t('plan.add')}
		/>
		<button class="btn btn-primary pressable" type="submit">{t('plan.add')}</button>
	</form>

	{#if plan.filter === 'today' && plan.visible.length > 0 && app.tier === 'free'}
		<p class="suggest-hint">✨ {t('plan.energyHint', { energy: t(`plan.energy.${suggestion}`) })}</p>
	{/if}

	{#if showCapNotice && plan.freeCapReached}
		<div class="cap card">
			🔒 {t('plan.capBlocked')}
			<a class="btn btn-soft pressable" href="/account">{t('plan.upgradeTeaser')}</a>
		</div>
	{/if}

	<div class="inspector-grid">
		<div class="list-area">
			{#if plan.visible.length === 0}
				<div class="empty card">
					<p class="empty-title">{t(EMPTY_KEYS[plan.filter])}</p>
					<p class="empty-body">{t('plan.empty.body')}</p>
				</div>
			{:else if plan.filter === 'completed'}
				<ul class="list">
					{#each plan.visible as task (task.id)}
						<TaskRow
							{task}
							selected={selectedId === task.id}
							onselect={() => selectTask(task.id)}
							ontoggle={() => plan.toggleComplete(task.id)}
							onfocus={() => focusTask(task)}
						/>
					{/each}
				</ul>
			{:else}
				<TaskTable
					tasks={plan.visible}
					selectedId={selectedId}
					onselect={selectTask}
					ontoggle={(id) => plan.toggleComplete(id)}
					onfocus={focusTask}
				/>
				<div class="mobile-list">
				{#each groupByEnergy(plan.visible) as group (group.energy)}
					<section class="group">
						<h2 class="group-title">{t(`plan.energy.${group.energy}`)}</h2>
						<ul class="list">
							{#each group.tasks as task (task.id)}
								<TaskRow
									{task}
									selected={selectedId === task.id}
									onselect={() => selectTask(task.id)}
									ontoggle={() => plan.toggleComplete(task.id)}
									onfocus={() => focusTask(task)}
									dragging={dragId === task.id}
									ondragstart={ondragstart(task.id)}
									ondragover={dragOverHandler()}
									ondrop={() => ondrop(task.id)}
								/>
							{/each}
						</ul>
					</section>
				{/each}
				</div>
			{/if}
		</div>

		<TaskInspector task={selectedTask} onclose={() => selectTask(null)} />
	</div>
</section>

<style>
	.plan {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		max-width: 1100px; /* wide, like the Mac plan table */
		margin-inline: auto;
		width: 100%;
	}

	.toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	.qc-open {
		border-style: dashed;
	}

	@media (max-width: 599px) {
		.qc-label {
			display: none;
		}
	}

	.quickadd {
		display: flex;
		gap: var(--space-2);
	}

	.quickadd .field {
		flex: 1;
	}

	.suggest-hint {
		color: var(--muted);
		font-size: var(--text-xs);
	}

	.cap {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		color: var(--ink-secondary);
		font-weight: 550;
	}

	.empty {
		padding: var(--space-10) var(--space-6);
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.empty-title {
		font-size: var(--text-md);
		font-weight: 650;
	}

	.empty-body {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.list-area {
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
	}

	.mobile-list {
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
	}

	@media (min-width: 1024px) {
		.mobile-list {
			display: none;
		}
	}

	@media (max-width: 1023px) {
		.list-area :global(.task-table) {
			display: none;
		}
	}

	.list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
	}

	.group-title {
		font-size: var(--text-xs);
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--muted);
		margin: 0 0 var(--space-1) var(--space-2);
	}
</style>
