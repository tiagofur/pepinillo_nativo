<script lang="ts">
	import { goto } from '$app/navigation';
	import { app } from '$lib/stores/app.svelte';
	import { t, type MessageKey } from '$lib/i18n/messages';
	import type { TaskEnergy, TaskList, TaskPriority } from '$lib/domain/entities/types';
	import { FREE_MAX_ACTIVE_TASKS } from '$lib/domain/entities/types';
	import EmptyIllustration from '$lib/components/EmptyIllustration.svelte';

	const locale = $derived(app.locale);

	let title = $state('');
	let priority = $state<TaskPriority>('medium');
	let energy = $state<TaskEnergy>('medium');
	let estimatedPomodoros = $state(1);
	let list = $state<TaskList>('inbox');
	let filter = $state<'all' | TaskList>('all');
	let capError = $state(false);
	let showOptions = $state(false);

	const filtered = $derived(
		app.activeTasks.filter((task) => (filter === 'all' ? true : task.list === filter))
	);

	const capRatio = $derived(
		Math.min(100, (app.activeTasks.length / FREE_MAX_ACTIVE_TASKS) * 100)
	);

	async function onAdd(e: Event) {
		e.preventDefault();
		if (!title.trim()) return;
		const result = await app.createTask({
			title,
			priority,
			energy,
			estimatedPomodoros,
			list
		});
		if (!result.ok) {
			capError = true;
			return;
		}
		capError = false;
		title = '';
	}

	async function move(id: string, delta: number) {
		const ids = app.activeTasks.map((t) => t.id);
		const idx = ids.indexOf(id);
		const next = idx + delta;
		if (idx < 0 || next < 0 || next >= ids.length) return;
		const copy = [...ids];
		const [item] = copy.splice(idx, 1);
		copy.splice(next, 0, item);
		await app.reorderTasks(copy);
	}

	async function focusTask(id: string) {
		app.setFocusTask(id);
		await goto('/focus/');
	}

	function priorityLabel(p: TaskPriority): string {
		return t(locale, `plan.priority.${p}` as MessageKey);
	}

	function energyLabel(e: TaskEnergy): string {
		return t(locale, `plan.energy.${e}` as MessageKey);
	}

	function listLabel(l: TaskList): string {
		return t(locale, `plan.filter.${l}` as MessageKey);
	}
</script>

<section class="panel plan-screen">
	<div class="panel-head">
		<div>
			<h1>{t(locale, 'plan.title')}</h1>
		</div>
		<div class="cap-meter" aria-label="{app.activeTasks.length} / {FREE_MAX_ACTIVE_TASKS}">
			<span class="cap-meter-text"
				>{app.activeTasks.length}/{FREE_MAX_ACTIVE_TASKS} {t(locale, 'plan.activeCap')}</span
			>
			<div class="cap-meter-track">
				<div
					class="cap-meter-fill"
					class:warn={app.activeTasks.length >= FREE_MAX_ACTIVE_TASKS}
					style="width: {capRatio}%"
				></div>
			</div>
		</div>
	</div>

	<form class="quick-add card" onsubmit={onAdd}>
		<div class="quick-add-row">
			<input
				id="task-title"
				class="quick-add-input"
				bind:value={title}
				placeholder={t(locale, 'plan.quickPlaceholder')}
				required
				aria-label={t(locale, 'plan.quickPlaceholder')}
			/>
			<button class="btn btn-primary quick-add-btn" type="submit">{t(locale, 'plan.add')}</button>
		</div>

		<button
			type="button"
			class="btn btn-ghost btn-sm options-toggle"
			onclick={() => (showOptions = !showOptions)}
		>
			{showOptions ? t(locale, 'plan.hideOptions') : t(locale, 'plan.showOptions')}
		</button>

		{#if showOptions}
			<div class="options-grid">
				<div class="field">
					<label for="priority">{t(locale, 'plan.priority')}</label>
					<select id="priority" bind:value={priority}>
						<option value="low">{t(locale, 'plan.priority.low')}</option>
						<option value="medium">{t(locale, 'plan.priority.medium')}</option>
						<option value="high">{t(locale, 'plan.priority.high')}</option>
					</select>
				</div>
				<div class="field">
					<label for="energy">{t(locale, 'plan.energy')}</label>
					<select id="energy" bind:value={energy}>
						<option value="low">{t(locale, 'plan.energy.low')}</option>
						<option value="medium">{t(locale, 'plan.energy.medium')}</option>
						<option value="high">{t(locale, 'plan.energy.high')}</option>
					</select>
				</div>
				<div class="field">
					<label for="pomos">{t(locale, 'plan.estPomos')}</label>
					<input id="pomos" type="number" min="1" max="12" bind:value={estimatedPomodoros} />
				</div>
				<div class="field">
					<label for="list">{t(locale, 'plan.listLabel')}</label>
					<select id="list" bind:value={list}>
						<option value="inbox">{t(locale, 'plan.filter.inbox')}</option>
						<option value="today">{t(locale, 'plan.filter.today')}</option>
						<option value="upcoming">{t(locale, 'plan.filter.upcoming')}</option>
					</select>
				</div>
			</div>
		{/if}
	</form>

	{#if capError || app.upgradeTeaser === 'tasks'}
		<p class="teaser">
			<strong>{t(locale, 'plan.capBlocked')}</strong>
			{t(locale, 'plan.upgradeTeaser')}
		</p>
	{/if}

	<div class="filter-scroll" role="group" aria-label="Filter">
		<button
			type="button"
			class="chip filter"
			class:active={filter === 'all'}
			aria-pressed={filter === 'all'}
			onclick={() => (filter = 'all')}
		>
			{t(locale, 'plan.filter.all')}
		</button>
		<button
			type="button"
			class="chip filter"
			class:active={filter === 'today'}
			aria-pressed={filter === 'today'}
			onclick={() => (filter = 'today')}
		>
			{t(locale, 'plan.filter.today')}
		</button>
		<button
			type="button"
			class="chip filter"
			class:active={filter === 'upcoming'}
			aria-pressed={filter === 'upcoming'}
			onclick={() => (filter = 'upcoming')}
		>
			{t(locale, 'plan.filter.upcoming')}
		</button>
		<button
			type="button"
			class="chip filter"
			class:active={filter === 'inbox'}
			aria-pressed={filter === 'inbox'}
			onclick={() => (filter = 'inbox')}
		>
			{t(locale, 'plan.filter.inbox')}
		</button>
	</div>

	{#if filtered.length === 0}
		<div class="empty-state">
			<EmptyIllustration kind="tasks" />
			<p class="muted" style="margin: 0 0 var(--space-3);">{t(locale, 'plan.empty')}</p>
			<button class="btn btn-primary" type="button" onclick={() => document.getElementById('task-title')?.focus()}>
				{t(locale, 'plan.add')}
			</button>
		</div>
	{:else}
		<ul class="task-list">
			{#each filtered as task (task.id)}
				<li class="task-row priority-{task.priority}">
					<button
						type="button"
						class="task-check"
						aria-label={t(locale, 'plan.complete')}
						onclick={() => app.completeTask(task.id)}
					></button>
					<div class="task-body">
						<h3 class="task-title">{task.title}</h3>
						<div class="task-meta">
							<span class="meta-pill priority-{task.priority}">{priorityLabel(task.priority)}</span>
							<span class="meta-pill">{energyLabel(task.energy)}</span>
							<span class="meta-pill">{task.estimatedPomodoros}p</span>
							<span class="meta-pill">{listLabel(task.list)}</span>
						</div>
						<div class="task-actions">
							<button class="btn btn-ghost btn-sm" type="button" onclick={() => focusTask(task.id)}>
								{t(locale, 'plan.focusTask')}
							</button>
							<button
								class="btn btn-ghost btn-sm icon-btn"
								type="button"
								aria-label="{t(locale, 'plan.reorder')} up"
								onclick={() => move(task.id, -1)}
							>
								↑
							</button>
							<button
								class="btn btn-ghost btn-sm icon-btn"
								type="button"
								aria-label="{t(locale, 'plan.reorder')} down"
								onclick={() => move(task.id, 1)}
							>
								↓
							</button>
							<button class="btn btn-ghost btn-sm" type="button" onclick={() => app.deleteTask(task.id)}>
								{t(locale, 'plan.delete')}
							</button>
						</div>
					</div>
				</li>
			{/each}
		</ul>
	{/if}
</section>
