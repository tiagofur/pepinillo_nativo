<script lang="ts">
	import Sheet from '$lib/design/Sheet.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { listActiveTasks } from '$lib/data/local/idb';
	import {
		FREE_SOUNDSCAPES,
		isSoundscapeFree,
		startSoundscape,
		type SoundscapeHandle
	} from '$lib/domain/audio/sounds';
	import type { SoundscapeName, Task } from '$lib/domain/entities/types';
	import { onMount } from 'svelte';
	import Icon from '$lib/design/Icon.svelte';

	let showTaskPicker = $state(false);
	let showSoundscape = $state(false);
	let tasks = $state<Task[]>([]);

	const RATINGS: { value: 1 | 2 | 3 | 4 | 5; key: MessageKey }[] = [
		{ value: 1, key: 'journal.rating.1' },
		{ value: 2, key: 'journal.rating.2' },
		{ value: 3, key: 'journal.rating.3' },
		{ value: 4, key: 'journal.rating.4' },
		{ value: 5, key: 'journal.rating.5' }
	];

	let rating = $state<0 | 1 | 2 | 3 | 4 | 5>(0);
	let note = $state('');

	const SOUNDSCAPES: { id: SoundscapeName; key: MessageKey }[] = [
		{ id: 'none', key: 'soundscape.none' },
		{ id: 'rain', key: 'soundscape.rain' },
		{ id: 'forest', key: 'soundscape.forest' },
		{ id: 'cafe', key: 'soundscape.cafe' },
		{ id: 'whiteNoise', key: 'soundscape.whiteNoise' },
		{ id: 'ocean', key: 'soundscape.ocean' },
		{ id: 'fireplace', key: 'soundscape.fireplace' },
		{ id: 'binaural', key: 'soundscape.binaural' },
		{ id: 'lofi', key: 'soundscape.lofi' }
	];

	async function openTaskPicker(): Promise<void> {
		tasks = await listActiveTasks();
		showTaskPicker = true;
	}

	function pickTask(task: Task | null): void {
		focus.setActiveTask(task);
		showTaskPicker = false;
	}

	function pickSoundscape(id: SoundscapeName): void {
		if (!isSoundscapeFree(id)) return;
		app.setSoundscape(id);
		focus.soundscapeChanged();
		showSoundscape = false;
	}

	function submitJournal(): void {
		if (rating === 0) return;
		focus.saveJournal(rating, note);
		rating = 0;
		note = '';
	}

	// Local preview when picking a soundscape outside a session.
	let preview: SoundscapeHandle | null = null;

	function previewSoundscape(id: SoundscapeName): void {
		if (id === 'none') {
			preview?.stop();
			preview = null;
			return;
		}
		if (!isSoundscapeFree(id)) return;
		preview?.stop();
		preview = startSoundscape(id, app.prefs.soundscapeVolume);
	}

	onMount(() => {
		return () => {
			preview?.stop();
		};
	});
</script>

<!-- Inline controls row -->
<div class="extras">
	<button class="chip glass-chip pressable" onclick={() => openTaskPicker()}>
		📋 {focus.activeTask ? focus.activeTask.title : t('focus.noTask')}
	</button>
	<button class="chip glass-chip pressable" onclick={() => (showSoundscape = true)}>
		🎧 {t(`soundscape.${app.prefs.soundscape}`)}
	</button>
</div>

<!-- Journal sheet -->
<Sheet open={focus.journalPrompt !== null} onclose={() => focus.dismissJournal()} title={t('journal.title')}>
	<div class="journal">
		<p class="muted">{t('journal.subtitle')}</p>
		<div class="ratings">
			{#each RATINGS as r (r.value)}
				<button
					class="rating pressable"
					class:is-active={rating === r.value}
					aria-pressed={rating === r.value}
					onclick={() => (rating = r.value)}
					title={t(r.key)}
				>
					<span class="face">{['😞', '😐', '🙂', '😊', '🔥'][r.value - 1]}</span>
					<span class="label">{t(r.key)}</span>
				</button>
			{/each}
		</div>
		<textarea
			class="field journal-note"
			rows="3"
			placeholder={t('journal.placeholder')}
			bind:value={note}
		></textarea>
		<div class="row-actions">
			<button class="btn btn-primary pressable" disabled={rating === 0} onclick={submitJournal}>
				{t('journal.save')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => focus.dismissJournal()}>
				{t('journal.skip')}
			</button>
		</div>
	</div>
</Sheet>

<!-- Task picker sheet -->
<Sheet open={showTaskPicker} onclose={() => (showTaskPicker = false)} title={t('taskPicker.title')}>
	{#if tasks.length === 0}
		<p class="muted">{t('taskPicker.empty')}</p>
	{:else}
		<ul class="task-list">
			{#each tasks as task (task.id)}
				<li>
					<button
						class="task-row pressable"
						class:is-active={focus.activeTask?.id === task.id}
						onclick={() => pickTask(focus.activeTask?.id === task.id ? null : task)}
					>
						<span>{task.title}</span>
						<span class="tomatoes nums">🍅 {task.estimatedPomodoros}</span>
					</button>
				</li>
			{/each}
		</ul>
	{/if}
	<button class="btn btn-ghost pressable unlink" onclick={() => pickTask(null)}>
		{t('taskPicker.unlink')}
	</button>
</Sheet>

<!-- Soundscape sheet -->
<Sheet open={showSoundscape} onclose={() => { preview?.stop(); preview = null; showSoundscape = false; }} title={t('soundscape.title')}>
	<div class="sound-grid">
		{#each SOUNDSCAPES as s (s.id)}
			{@const free = FREE_SOUNDSCAPES.includes(s.id)}
			<button
				class="chip pressable sound-chip"
				aria-pressed={app.prefs.soundscape === s.id}
				class:is-active={app.prefs.soundscape === s.id}
				class:is-locked={!free}
				disabled={!free}
				onclick={() => pickSoundscape(s.id)}
				onmouseenter={() => previewSoundscape(s.id)}
				title={free ? t(s.key) : t('common.proLocked')}
			>
				{#if free}
					{t(s.key)}
				{:else}
					<Icon name="lock" size={13} /> {t(s.key)}
				{/if}
			</button>
		{/each}
	</div>
	<label class="volume">
		<span>{t('soundscape.volume')}</span>
		<input
			type="range"
			min="0"
			max="1"
			step="0.05"
			value={app.prefs.soundscapeVolume}
			oninput={(e) => app.setSoundscapeVolume(Number(e.currentTarget.value))}
		/>
	</label>
	<p class="muted hint">{t('soundscape.hint')}</p>
</Sheet>

<style>
	.extras {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: var(--space-2);
		max-width: 560px;
	}

	.extras .chip {
		max-width: 260px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.journal {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.muted {
		color: var(--muted);
	}

	.ratings {
		display: flex;
		gap: var(--space-2);
		justify-content: space-between;
	}

	.rating {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		min-height: 72px;
		padding: var(--space-2);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface);
		cursor: pointer;
	}

	.rating.is-active {
		background: var(--brand-soft);
		border-color: var(--brand);
	}

	.face {
		font-size: 26px;
	}

	.label {
		font-size: var(--text-2xs);
		color: var(--muted);
	}

	.journal-note {
		resize: vertical;
	}

	.row-actions {
		display: flex;
		gap: var(--space-3);
	}

	.task-list {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.task-row {
		width: 100%;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: var(--space-3);
		min-height: var(--touch-target);
		padding: 0 var(--space-4);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface);
		cursor: pointer;
		text-align: start;
	}

	.task-row.is-active {
		background: var(--brand-soft);
		border-color: var(--brand);
	}

	.tomatoes {
		color: var(--muted);
		font-size: var(--text-sm);
		flex: none;
	}

	.unlink {
		margin-top: var(--space-3);
	}

	.sound-grid {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.volume {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		margin-top: var(--space-4);
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.volume input {
		flex: 1;
		accent-color: var(--brand);
	}

	.hint {
		font-size: var(--text-xs);
	}
</style>
