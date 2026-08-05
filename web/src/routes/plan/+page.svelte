<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/messages';
	import type { TaskEnergy, TaskList, TaskPriority } from '$lib/domain/entities/types';
	import { FREE_MAX_ACTIVE_TASKS } from '$lib/domain/entities/types';

	const locale = $derived(app.locale);

	let title = $state('');
	let priority = $state<TaskPriority>('medium');
	let energy = $state<TaskEnergy>('medium');
	let estimatedPomodoros = $state(1);
	let list = $state<TaskList>('inbox');
	let filter = $state<'all' | TaskList>('all');
	let capError = $state(false);

	const filtered = $derived(
		app.activeTasks.filter((task) => (filter === 'all' ? true : task.list === filter))
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
</script>

<section class="panel">
	<div class="panel-head">
		<h1>{t(locale, 'plan.title')}</h1>
		<span class="muted"
			>{app.activeTasks.length}/{FREE_MAX_ACTIVE_TASKS} active</span
		>
	</div>

	<form class="stack" onsubmit={onAdd}>
		<div class="field">
			<label for="task-title">Task</label>
			<input id="task-title" bind:value={title} placeholder="What needs focus?" required />
		</div>
		<div class="row">
			<div class="field" style="flex: 1; min-width: 8rem;">
				<label for="priority">{t(locale, 'plan.priority')}</label>
				<select id="priority" bind:value={priority}>
					<option value="low">low</option>
					<option value="medium">medium</option>
					<option value="high">high</option>
				</select>
			</div>
			<div class="field" style="flex: 1; min-width: 8rem;">
				<label for="energy">{t(locale, 'plan.energy')}</label>
				<select id="energy" bind:value={energy}>
					<option value="low">low</option>
					<option value="medium">medium</option>
					<option value="high">high</option>
				</select>
			</div>
			<div class="field" style="flex: 1; min-width: 8rem;">
				<label for="pomos">{t(locale, 'plan.estPomos')}</label>
				<input
					id="pomos"
					type="number"
					min="1"
					max="12"
					bind:value={estimatedPomodoros}
				/>
			</div>
			<div class="field" style="flex: 1; min-width: 8rem;">
				<label for="list">List</label>
				<select id="list" bind:value={list}>
					<option value="inbox">inbox</option>
					<option value="today">today</option>
					<option value="upcoming">upcoming</option>
				</select>
			</div>
		</div>
		<button class="btn btn-primary" type="submit">{t(locale, 'plan.add')}</button>
	</form>

	{#if capError || app.upgradeTeaser === 'tasks'}
		<p class="teaser">
			<strong>{t(locale, 'plan.capBlocked')}</strong>
			{t(locale, 'plan.upgradeTeaser')}
		</p>
	{/if}

	<div class="row" role="group" aria-label="Filter">
		<button
			type="button"
			class="chip"
			class:active={filter === 'all'}
			aria-pressed={filter === 'all'}
			onclick={() => (filter = 'all')}
		>
			{t(locale, 'plan.filter.all')}
		</button>
		<button
			type="button"
			class="chip"
			class:active={filter === 'today'}
			aria-pressed={filter === 'today'}
			onclick={() => (filter = 'today')}
		>
			{t(locale, 'plan.filter.today')}
		</button>
		<button
			type="button"
			class="chip"
			class:active={filter === 'upcoming'}
			aria-pressed={filter === 'upcoming'}
			onclick={() => (filter = 'upcoming')}
		>
			{t(locale, 'plan.filter.upcoming')}
		</button>
		<button
			type="button"
			class="chip"
			class:active={filter === 'inbox'}
			aria-pressed={filter === 'inbox'}
			onclick={() => (filter = 'inbox')}
		>
			{t(locale, 'plan.filter.inbox')}
		</button>
	</div>

	{#if filtered.length === 0}
		<p class="muted">{t(locale, 'plan.empty')}</p>
	{:else}
		<ul class="task-list">
			{#each filtered as task (task.id)}
				<li class="task-item">
					<div>
						<h3>{task.title}</h3>
						<p class="muted">
							{task.priority} · {task.energy} · {task.estimatedPomodoros}p · {task.list}
						</p>
					</div>
					<div class="row">
						<button
							class="btn btn-ghost"
							type="button"
							aria-label="Move up"
							onclick={() => move(task.id, -1)}
						>
							↑
						</button>
						<button
							class="btn btn-ghost"
							type="button"
							aria-label="Move down"
							onclick={() => move(task.id, 1)}
						>
							↓
						</button>
						<button class="btn btn-ghost" type="button" onclick={() => app.completeTask(task.id)}>
							{t(locale, 'plan.complete')}
						</button>
						<button class="btn btn-ghost" type="button" onclick={() => app.deleteTask(task.id)}>
							{t(locale, 'plan.delete')}
						</button>
					</div>
				</li>
			{/each}
		</ul>
	{/if}
</section>
