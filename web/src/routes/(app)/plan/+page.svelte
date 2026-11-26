<script lang="ts">
	import { onMount } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import TaskRow from '$lib/features/plan/TaskRow.svelte';
	import TaskTable from '$lib/features/plan/TaskTable.svelte';
	import TaskInspector from '$lib/features/plan/TaskInspector.svelte';
	import PaneToolbar from '$lib/features/shell/PaneToolbar.svelte';
	import ContextMenu, { type ContextMenuItem } from '$lib/features/shell/ContextMenu.svelte';
	import Segmented from '$lib/design/Segmented.svelte';
	import Icon from '$lib/design/Icon.svelte';
	import { groupByEnergy, PLAN_FILTERS, quickAddDefaults, type PlanFilter } from '$lib/domain/tasks/plan';
	import type { TaskEnergy } from '$lib/domain/entities/types';
	import { suggestEnergy } from '$lib/domain/tasks/energy';
	import type { Task } from '$lib/domain/entities/types';

	onMount(() => {
		void plan.init();
		// Mac window commands raised by the shell (⌘F / ⌘N / ⌘⌥I).
		function planCommand(command: string): void {
			if (command === 'pepinillo:plan-search') searchEl?.focus();
			else if (command === 'pepinillo:plan-new-task') focusComposer();
			else if (command === 'pepinillo:plan-inspector') toggleInspector();
		}
		function onPlanCommand(e: Event): void {
			planCommand(e.type);
		}
		window.addEventListener('pepinillo:plan-search', onPlanCommand);
		window.addEventListener('pepinillo:plan-new-task', onPlanCommand);
		window.addEventListener('pepinillo:plan-inspector', onPlanCommand);
		// Shell may have parked a command raised before this page mounted.
		const w = window as unknown as { pepinilloPlanCommand?: string };
		const pending = w.pepinilloPlanCommand;
		delete w.pepinilloPlanCommand;
		if (pending) planCommand(pending);
		return () => {
			window.removeEventListener('pepinillo:plan-search', onPlanCommand);
			window.removeEventListener('pepinillo:plan-new-task', onPlanCommand);
			window.removeEventListener('pepinillo:plan-inspector', onPlanCommand);
		};
	});

	// Mac sidebar filters: Todas / Hoy / Próximas / Completadas.
	const FILTER_KEYS: { id: PlanFilter; key: MessageKey }[] = [
		{ id: 'all', key: 'plan.filter.all' },
		{ id: 'today', key: 'plan.filter.today' },
		{ id: 'upcoming', key: 'plan.filter.upcoming' },
		{ id: 'completed', key: 'plan.filter.completed' }
	];

	const EMPTY_KEYS: Record<PlanFilter, MessageKey> = {
		all: 'plan.empty.all',
		today: 'plan.empty.today',
		inbox: 'plan.empty.inbox',
		upcoming: 'plan.empty.upcoming',
		completed: 'plan.empty.completed'
	};

	/** Mac ContentUnavailableView per-filter garden descriptions. */
	const EMPTY_DESC_KEYS: Record<PlanFilter, MessageKey> = {
		all: 'plan.empty.all.desc',
		today: 'plan.empty.today.desc',
		inbox: 'plan.empty.inbox.desc',
		upcoming: 'plan.empty.upcoming.desc',
		completed: 'plan.empty.completed.desc'
	};

	let quickValue = $state('');
	let selectedId = $state<string | null>(null);
	let dragId = $state<string | null>(null);
	let showCapNotice = $state(false);
	let query = $state('');

	let searchEl = $state<HTMLInputElement | null>(null);
	let quickAddEl = $state<HTMLInputElement | null>(null);
	let newtaskEl = $state<HTMLInputElement | null>(null);

	/** ⌘N: focus whichever composer is visible (bottom row on desktop). */
	function focusComposer(): void {
		const el = newtaskEl && newtaskEl.offsetParent !== null ? newtaskEl : quickAddEl;
		el?.focus();
	}

	let selectedTask = $derived(plan.tasks.find((x) => x.id === selectedId) ?? null);
	let suggestion = $derived(suggestEnergy(new Date().getHours()));

	/* Issue #990: the energy suggestion is an actionable Today-scoped filter
	 * (S2–S4). Not persisted; dismissal lasts the session. Hidden when the
	 * suggested level has no candidate tasks (S3). */
	let energyFilter = $state<TaskEnergy | null>(null);
	let suggestionDismissed = $state(false);
	$effect(() => {
		void plan.filter;
		energyFilter = null;
	});
	let suggestionVisible = $derived(
		plan.filter === 'today' &&
			!suggestionDismissed &&
			(energyFilter !== null || plan.visible.some((t) => t.energy === suggestion))
	);

	/** Toolbar search (Mac `.searchable`): narrows the visible subset by title. */
	let displayed = $derived.by(() => {
		const base = energyFilter ? plan.visible.filter((task) => task.energy === energyFilter) : plan.visible;
		const q = query.trim().toLowerCase();
		if (!q) return base;
		return base.filter((task) => task.title.toLowerCase().includes(q));
	});

	/** ⌘⌥I / toolbar toggle: open the inspector on the first visible task. */
	function toggleInspector(): void {
		if (selectedId) selectTask(null);
		else if (displayed.length > 0) selectTask(displayed[0].id);
	}

	// ---- Context menu (MacPlanView contextMenu parity) ----
	let ctx = $state<{ task: Task; x: number; y: number } | null>(null);

	// No row selection side effect: on mobile it would pop the inspector
	// Sheet behind the menu (double modal); Mac selects only on left-click.
	function openContext(task: Task, x: number, y: number): void {
		ctx = { task, x, y };
	}

	let ctxItems = $derived<ContextMenuItem[]>(ctx ? buildContextItems(ctx.task) : []);

	/** Context-menu "Rename Task": desktop enters the table's inline title
	 * edit (consumed by TaskTable); mobile has no table, so it opens the
	 * inspector where title editing lives. */
	let renameRequest = $state<string | null>(null);

	function requestRename(task: Task): void {
		if (window.matchMedia('(max-width: 1023px)').matches) selectTask(task.id);
		else renameRequest = task.id;
	}

	function buildContextItems(task: Task): ContextMenuItem[] {
		// Mac menu order: Priority sorted(by: >) → high, medium, low, none.
		const PRIORITY_KEYS = ['high', 'medium', 'low', 'none'] as const;
		const ENERGY_KEYS = ['deep', 'shallow', 'admin'] as const;
		const completed = task.status === 'completed';
		return [
			{
				id: 'rename',
				label: t('plan.context.rename'),
				onselect: () => requestRename(task)
			},
			{ id: 'sep0', kind: 'separator' },
			{
				id: 'focus',
				label: t('plan.focusTask'),
				disabled: completed,
				onselect: () => focusTask(task)
			},
			{
				id: 'toggle',
				label: completed ? t('plan.markIncomplete') : t('plan.complete'),
				onselect: () => void plan.toggleComplete(task.id)
			},
			{ id: 'sep1', kind: 'separator' },
			{
				id: 'priority',
				label: t('plan.priority'),
				kind: 'submenu',
				children: PRIORITY_KEYS.map((p) => ({
					id: p,
					label: t(`plan.priority.${p}` as MessageKey),
					checked: task.priority === p,
					onselect: () => void plan.updateTask(task.id, { priority: p })
				}))
			},
			{
				id: 'energy',
				label: t('plan.energy'),
				kind: 'submenu',
				children: ENERGY_KEYS.map((e) => ({
					id: e,
					label: t(`plan.energy.${e}` as MessageKey),
					checked: task.energy === e,
					onselect: () => void plan.updateTask(task.id, { energy: e })
				}))
			},
			{
				// «Planificar para…» (issue #991): the inspector hosts the native
				// date input; the menu keeps the quick days + removal.
				id: 'planFor',
				label: t('plan.scheduleFor'),
				kind: 'submenu',
				children: [
					{
						id: 'planToday',
						label: t('plan.filter.today'),
						checked: task.plannedDate === localDateKey(new Date()),
						onselect: () =>
							void plan.updateTask(task.id, { plannedDate: localDateKey(new Date()), scheduledForToday: true })
					},
					{
						id: 'planTomorrow',
						label: t('plan.planTomorrow'),
						onselect: () => {
							const d = new Date();
							d.setDate(d.getDate() + 1);
							void plan.updateTask(task.id, { plannedDate: localDateKey(d), scheduledForToday: false });
						}
					},
					{
						id: 'planWeekend',
						label: t('plan.planWeekend'),
						onselect: () => {
							const d = new Date();
							const delta = (6 - d.getDay() + 7) % 7 || 7;
							d.setDate(d.getDate() + delta);
							void plan.updateTask(task.id, { plannedDate: localDateKey(d), scheduledForToday: false });
						}
					},
					...(task.plannedDate
						? [
								{
									id: 'planRemove',
									label: t('plan.removeDate'),
									destructive: true,
									onselect: () => void plan.updateTask(task.id, { plannedDate: null })
								}
							]
						: [])
				]
			},
			{ id: 'sep2', kind: 'separator' },
			{
				id: 'delete',
				label: t('plan.delete'),
				destructive: true,
				onselect: () => void plan.deleteTask(task.id)
			}
		];
	}

	async function quickAdd(): Promise<void> {
		const defaults = quickAddDefaults(plan.filter);
		const created = await plan.addTask(quickValue, defaults);
		if (!created) {
			// Cap blocked: keep the typed text so the user loses nothing.
			showCapNotice = true;
			return;
		}
		quickValue = '';
	}

	function selectTask(id: string | null): void {
		selectedId = id;
	}

	function focusTask(task: Task): void {
		plan.focusOn(task);
		// Mac startFocusOnTask parity: the session starts immediately, not
		// just pre-linked (only when nothing is live).
		if (focus.idle && !focus.waiting) focus.start();
		void gotoFocus();
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
	<!-- Mac window toolbar: search + inspector toggle + new task -->
	<PaneToolbar title={t('plan.title')}>
		{#snippet right()}
			<label class="pt-search">
				<Icon name="search" size={14} />
				<input
					bind:this={searchEl}
					bind:value={query}
					placeholder={t('plan.search')}
					aria-label={t('plan.search')}
				/>
				<button
					class="pt-kbd pressable"
					title={t('quickCapture.hint')}
					aria-label={t('quickCapture.title')}
					onclick={() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true }))}
				>⌘K</button>
			</label>
			<span class="pt-group">
				<button
					class="pt-btn pressable"
					class:is-on={!!selectedTask}
					title={t('plan.inspector')}
					aria-label={t('plan.inspector')}
					aria-pressed={!!selectedTask}
					onclick={toggleInspector}
				>
					<Icon name="inspector" size={16} />
				</button>
				<button
					class="pt-btn pressable"
					title={t('plan.newTask')}
					aria-label={t('plan.newTask')}
					onclick={focusComposer}
				>
					<Icon name="plus" size={16} />
				</button>
			</span>
		{/snippet}
	</PaneToolbar>

	<div class="plan-scroll">
	<div class="toolbar">
		<Segmented
			options={FILTER_KEYS.map((f) => ({ id: f.id, label: t(f.key) }))}
			value={plan.filter}
			onchange={(id) => plan.setFilter(id as PlanFilter)}
		/>
		<button
			class="chip chip-soft pressable qc-open"
			onclick={() => window.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', metaKey: true }))}
			title={t('quickCapture.hint')}
		>
			⚡ <span class="qc-label">{t('quickCapture.title')}</span>
		</button>
	</div>

	<form
		class="quickadd"
		onsubmit={(e) => {
			e.preventDefault();
			void quickAdd();
		}}
	>
		<input
			bind:this={quickAddEl}
			class="field"
			placeholder={t('plan.quickPlaceholder')}
			bind:value={quickValue}
			aria-label={t('plan.add')}
		/>
		<button class="btn btn-primary pressable" type="submit">{t('plan.add')}</button>
	</form>
	{#if app.tier === 'free'}
		{#snippet capFeedback()}
			<p class="cap-counter nums" aria-live="polite">{t('plan.capCounter', { n: plan.activeCount })}</p>
			{#if showCapNotice && plan.freeCapReached}
				<p class="cap-inline" role="alert">
					🔒 {t('plan.capInline')}
					<a href="/upgrade">{t('plan.upgradeCta')} →</a>
				</p>
			{/if}
		{/snippet}
		{@render capFeedback()}
	{/if}

		<div class="inspector-grid" class:with-inspector={!!selectedTask}>
		<div class="list-area">
			{#if suggestionVisible}
				<div class="energy-prompt" role="group">
					{#if energyFilter}
						<span class="energy-active">
							✨ {t(`plan.energy.${energyFilter}`)} · {t('plan.energyFilterActive')}
							<button class="pill-action pressable" onclick={() => (energyFilter = null)}>
								{t('plan.showAll')}
							</button>
						</span>
					{:else}
						<button
							class="suggest-pill pressable"
							onclick={() => (energyFilter = suggestion)}
							aria-label={t('plan.energyFilterAria', { energy: t(`plan.energy.${suggestion}`) })}
						>
							✨ {t(`plan.energy.${suggestion}`)} · {t('plan.energySuggestedNow')}
						</button>
						<button
							class="pill-dismiss"
							onclick={() => (suggestionDismissed = true)}
							aria-label={t('plan.energyDismissAria')}
						>✕</button>
					{/if}
				</div>
			{/if}
			{#if displayed.length === 0}
				<!-- Mac ContentUnavailableView: symbol, title, description and the
					 contextual action directly on the content background -->
				<div class="empty">
					<span class="empty-icon" aria-hidden="true">
						<Icon name={query.trim() ? 'search' : 'plan'} size={40} />
					</span>
					<p class="empty-title">
						{query.trim() ? t('plan.empty.search.title') : t(EMPTY_KEYS[plan.filter])}
					</p>
					<p class="empty-body">
						{query.trim() ? t('plan.empty.search.desc') : t(EMPTY_DESC_KEYS[plan.filter])}
					</p>
					{#if query.trim()}
						<button class="btn btn-soft pressable" onclick={() => (query = '')}>
							{t('plan.empty.action.clear')}
						</button>
					{:else if plan.filter !== 'completed'}
						<button class="btn btn-primary pressable" onclick={focusComposer}>
							<Icon name="plus" size={15} />
							{t('plan.newTask')}
						</button>
					{/if}
				</div>
			{:else if plan.filter === 'completed'}
				<ul class="list">
					{#each displayed as task (task.id)}
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
					tasks={displayed}
					selectedId={selectedId}
					compact={!!selectedTask}
					onselect={selectTask}
					ontoggle={(id) => plan.toggleComplete(id)}
					oncontext={openContext}
					startRenameId={renameRequest}
					onrenamehandled={() => (renameRequest = null)}
				/>
				<div class="mobile-list">
				{#each groupByEnergy(displayed) as group (group.energy)}
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
									oncontext={(x, y) => openContext(task, x, y)}
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

	{#if showCapNotice && plan.freeCapReached}
		<div class="cap card" role="alert">
			<span class="cap-text">🔒 {t('plan.capBlocked')} {t('plan.upgradeTeaser')}</span>
			<a class="btn btn-soft pressable cap-cta" href="/upgrade">{t('plan.upgradeCta')}</a>
		</div>
	{/if}
	</div>

	<!-- Desktop: Reminders-style fixed "New task" row at the foot of the plan -->
	<form
		class="newtask"
		onsubmit={(e) => {
			e.preventDefault();
			void quickAdd();
		}}
	>
		<button class="nt-plus pressable" type="submit" aria-label={t('plan.newTask')} tabindex="-1">
			<Icon name="plus" size={16} />
		</button>
		<input
			bind:this={newtaskEl}
			placeholder={t('plan.newTask')}
			bind:value={quickValue}
			aria-label={t('plan.newTask')}
		/>
		{#if app.tier === 'free'}
			<span class="cap-counter nums">{t('plan.capCounter', { n: plan.activeCount })}</span>
			{#if showCapNotice && plan.freeCapReached}
				<span class="cap-inline" role="alert">
					🔒 {t('plan.capInline')}
					<a href="/upgrade">{t('plan.upgradeCta')} →</a>
				</span>
			{/if}
		{/if}
	</form>


	{#if ctx}
		<ContextMenu x={ctx.x} y={ctx.y} items={ctxItems} onclose={() => (ctx = null)} />
	{/if}
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

	/* Desktop: the plan scrolls INSIDE its column and the New-task bar sits
	 * statically at the foot — always visible, never overlaying content. */
	@media (min-width: 1024px) {
		.plan {
			height: 100%;
		}

		.plan-scroll {
			flex: 1;
			min-height: 0;
			overflow-y: auto;
		}
	}

	/* <=1023px: the wrapper is unstyled, so it must carry the .plan flex gap
	 * its children lost when they left the parent flex context */
	@media (max-width: 1023px) {
		.plan-scroll {
			display: flex;
			flex-direction: column;
			gap: var(--space-4);
		}
	}

	.toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	/* Desktop: filters live in the sidebar (Mac model); ⌘K stays global */
	@media (min-width: 1024px) {
		.toolbar {
			display: none;
		}
	}

	.qc-open {
		background: var(--brand-soft);
		border-color: transparent;
		color: var(--brand);
		font-weight: 650;
	}

	.quickadd {
		display: flex;
		gap: var(--space-2);
	}

	/* Desktop uses the Reminders-style bottom row instead */
	@media (min-width: 1024px) {
		.quickadd {
			display: none;
		}
	}

	.quickadd .field {
		flex: 1;
	}

	/* Mac bottom "New task" row (MacPlanView bottom safe area): pinned to the
	 * foot of the content column, bar background, accent plus, plain text. */
	.newtask {
		display: flex;
		flex: none;
		align-items: center;
		gap: var(--space-3);
		margin: var(--space-4) calc(-1 * var(--space-8)) calc(-1 * (var(--space-10) + var(--safe-b)));
		padding: var(--space-3) var(--space-6) calc(var(--space-6) + var(--safe-b));
		background: var(--bg);
		border-top: 1px solid var(--hairline);
		box-shadow: 0 -1px 0 var(--bg);
	}

	.nt-plus {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		flex: none;
		border: none;
		border-radius: 50%;
		background: var(--brand);
		color: var(--on-brand);
		cursor: pointer;
	}

	.newtask input {
		flex: 1;
		min-width: 0;
		border: none;
		background: transparent;
		color: var(--ink);
		font-size: var(--text-base);
	}

	.newtask input::placeholder {
		color: var(--muted);
	}

	.newtask input:focus {
		outline: none;
		box-shadow: none;
	}

	@media (max-width: 1023px) {
		.newtask {
			display: none;
		}
	}

	@media (min-width: 1024px) {
		.newtask {
			margin-inline: calc(-1 * var(--space-8));
		}


	}

	.energy-prompt {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 8px;
	}
	.suggest-pill,
	.energy-active {
		font-size: 0.85rem;
		font-weight: 600;
		color: var(--fg);
		background: var(--surface-2);
		border: 1px solid var(--border);
		border-radius: 999px;
		padding: 6px 14px;
		min-height: 36px;
	}
	.suggest-pill {
		cursor: pointer;
	}
	.pill-action {
		margin-inline-start: 8px;
		background: none;
		border: none;
		color: var(--accent);
		font: inherit;
		font-weight: 600;
		cursor: pointer;
		min-height: 36px;
	}
	.pill-dismiss {
		background: none;
		border: none;
		color: var(--fg-muted);
		cursor: pointer;
		min-height: 36px;
		min-width: 36px;
	}

	.cap {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		flex-wrap: wrap;
		padding: var(--space-3) var(--space-4);
		color: var(--ink-secondary);
		font-size: var(--text-sm);
	}

	.cap-text {
		flex: 1;
		min-width: 200px;
	}

	.cap-counter {
		font-size: var(--text-2xs);
		color: var(--faint);
		font-variant-numeric: tabular-nums;
	}

	.cap-inline {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
		margin: 0;
		color: var(--mode-pomodoro);
		font-size: var(--text-xs);
		font-weight: 600;
	}

	.cap-inline a {
		color: var(--brand);
		font-weight: 650;
	}

	/* Desktop: the feedback lives inside the .newtask row (right-aligned) */
	@media (min-width: 1024px) {
		.newtask .cap-counter {
			flex: none;
			margin-left: var(--space-2);
		}

		.newtask .cap-inline {
			flex: none;
		}

		/* The standalone feedback block after .quickadd is mobile-only */
		.quickadd ~ .cap-counter,
		.quickadd ~ .cap-inline {
			display: none;
		}
	}

	@media (max-width: 1023px) {
		.newtask .cap-counter,
		.newtask .cap-inline {
			display: none;
		}
	}

	.cap-cta {
		flex: none;
		padding: 0 var(--space-4);
		min-height: 34px;
		font-size: var(--text-sm);
	}

	.empty {
		padding: var(--space-10) var(--space-6);
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
	}

	.empty-icon {
		color: var(--faint);
	}

	.empty :global(.btn) {
		min-height: 34px;
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
	.pt-kbd {
		flex: none;
		font-family: var(--font-mono);
		font-size: var(--text-2xs);
		color: var(--faint);
		border: 1px solid var(--border);
		border-radius: 4px;
		padding: 1px 5px;
		background: none;
		cursor: pointer;
	}
</style>
