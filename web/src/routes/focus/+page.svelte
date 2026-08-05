<script lang="ts">
	import { app, TIER } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/messages';
	import { formatMs } from '$lib/format/time';
	import { canUseMode } from '$lib/domain/gates/freeLimits';
	import { remainingMs } from '$lib/domain/focus/engine';
	import type { FocusMode } from '$lib/domain/entities/types';

	const locale = $derived(app.locale);
	const session = $derived(app.focusSession);
	const modes: FocusMode[] = ['pomodoro', 'stopwatch', 'flowtime', 'timeblock'];

	const displayMs = $derived.by(() => {
		const iso = new Date(app.nowMs).toISOString();
		if (session.mode === 'pomodoro' && session.targetMs != null) {
			return remainingMs(session, iso) ?? 0;
		}
		return app.displayElapsedMs;
	});

	const progress = $derived.by(() => {
		if (session.targetMs == null || session.targetMs === 0) {
			/* count-up floor so ring is never empty at start (parity with mobile) */
			if (session.mode === 'stopwatch' || session.mode === 'flowtime') {
				return Math.min(100, Math.max(4, (app.displayElapsedMs / (50 * 60 * 1000)) * 100));
			}
			return 0;
		}
		const elapsed = app.displayElapsedMs;
		return Math.min(100, (elapsed / session.targetMs) * 100);
	});

	const ringColor = $derived(
		session.mode === 'stopwatch'
			? 'var(--mode-stopwatch)'
			: session.mode === 'flowtime'
				? 'var(--mode-flowtime)'
				: session.mode === 'timeblock'
					? 'var(--mode-timeblock)'
					: 'var(--mode-pomodoro)'
	);

	const status = $derived(session.status);

	function modeLabel(mode: FocusMode): string {
		switch (mode) {
			case 'pomodoro':
				return t(locale, 'focus.mode.pomodoro');
			case 'stopwatch':
				return t(locale, 'focus.mode.stopwatch');
			case 'flowtime':
				return t(locale, 'focus.mode.flowtime');
			case 'timeblock':
				return t(locale, 'focus.mode.timeblock');
		}
	}
</script>

<section class="panel">
	<div class="panel-head">
		<h1>{t(locale, 'focus.title')}</h1>
	</div>

	<p class="banner banner-soft">{t(locale, 'focus.honesty')}</p>

	<div class="mode-row" role="group" aria-label="Focus mode">
		{#each modes as mode (mode)}
			{@const allowed = canUseMode(mode, TIER)}
			<button
				type="button"
				class="chip {mode}"
				class:active={app.selectedMode === mode && allowed}
				class:locked={!allowed}
				aria-pressed={app.selectedMode === mode && allowed}
				onclick={() => app.selectMode(mode)}
			>
				{modeLabel(mode)}
				{#if !allowed}
					<span aria-hidden="true"> 🔒</span>
				{/if}
			</button>
		{/each}
	</div>

	{#if app.upgradeTeaser === 'mode'}
		<p class="teaser">{t(locale, 'focus.upgradeTeaser')}</p>
	{/if}

	<div class="focus-hero">
		<div
			class="timer-ring"
			style="--progress: {progress}%; --ring-color: {ringColor};"
			aria-live="polite"
		>
			<div class="timer-inner">
				<span class="timer-display">{formatMs(displayMs)}</span>
				<span class="timer-phase">
					<span class="timer-mode-dot" aria-hidden="true"></span>
					{modeLabel(session.mode)} · {status}
				</span>
			</div>
		</div>

		<div class="actions-row" style="--action-color: {ringColor};">
			{#if status === 'idle'}
				<button class="btn btn-mode" type="button" onclick={() => app.startFocus()}>
					{t(locale, 'focus.start')}
				</button>
			{:else if status === 'running'}
				<button class="btn btn-mode" type="button" onclick={() => app.pauseFocus()}>
					{t(locale, 'focus.pause')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.skipFocus()}>
					{t(locale, 'focus.skip')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.completeFocus()}>
					{t(locale, 'focus.complete')}
				</button>
			{:else if status === 'paused'}
				<button class="btn btn-mode" type="button" onclick={() => app.resumeFocus()}>
					{t(locale, 'focus.resume')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.skipFocus()}>
					{t(locale, 'focus.skip')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.completeFocus()}>
					{t(locale, 'focus.complete')}
				</button>
			{:else}
				<button class="btn btn-mode" type="button" onclick={() => app.resetFocus()}>
					{t(locale, 'focus.reset')}
				</button>
			{/if}
		</div>
	</div>

	<div class="card">
		<div class="field" style="margin-bottom: var(--space-3);">
			<label for="link-task">{t(locale, 'focus.linkTask')}</label>
			<select
				id="link-task"
				value={session.taskId ?? ''}
				onchange={(e) => {
					const v = (e.currentTarget as HTMLSelectElement).value;
					app.setFocusTask(v === '' ? null : v);
				}}
			>
				<option value="">{t(locale, 'focus.noTask')}</option>
				{#each app.activeTasks as task (task.id)}
					<option value={task.id}>{task.title}</option>
				{/each}
			</select>
		</div>

		<div class="field" style="margin-bottom: var(--space-3);">
			<label for="journal">{t(locale, 'focus.journal')}</label>
			<textarea
				id="journal"
				value={session.journal}
				oninput={(e) => app.setFocusJournal((e.currentTarget as HTMLTextAreaElement).value)}
			></textarea>
		</div>

		<label class="row muted" style="margin: 0;">
			<input
				type="checkbox"
				checked={app.prefs.autoStartNext}
				onchange={(e) =>
					app.updatePrefs({ autoStartNext: (e.currentTarget as HTMLInputElement).checked })}
			/>
			{t(locale, 'focus.autoStart')}
		</label>
	</div>
</section>
