<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t, type MessageKey } from '$lib/i18n/messages';
	import { formatMs } from '$lib/format/time';
	import { canUseMode } from '$lib/domain/gates/freeLimits';
	import { remainingMs } from '$lib/domain/focus/engine';
	import { suggestMode } from '$lib/domain/intelligence/modeSuggest';
	import type { FocusMode } from '$lib/domain/entities/types';
	import ModeIcons from '$lib/components/icons/ModeIcons.svelte';

	const locale = $derived(app.locale);
	const session = $derived(app.focusSession);
	const modes: FocusMode[] = ['pomodoro', 'stopwatch', 'flowtime', 'timeblock'];
	const sessionActive = $derived(session.status === 'running' || session.status === 'paused');

	const suggestion = $derived(suggestMode(new Date(app.nowMs)));

	const displayMs = $derived.by(() => {
		const iso = new Date(app.nowMs).toISOString();
		if (session.mode === 'pomodoro' && session.targetMs != null) {
			return remainingMs(session, iso) ?? 0;
		}
		return app.displayElapsedMs;
	});

	const progress = $derived.by(() => {
		if (session.targetMs == null || session.targetMs === 0) {
			if (session.mode === 'stopwatch' || session.mode === 'flowtime') {
				return Math.min(100, Math.max(4, (app.displayElapsedMs / (50 * 60 * 1000)) * 100));
			}
			return session.status === 'idle' ? 100 : 0;
		}
		const elapsed = app.displayElapsedMs;
		/* remaining fraction like Android ring (full at start) */
		const remaining = Math.max(0, 1 - elapsed / session.targetMs);
		return Math.min(100, remaining * 100);
	});

	const ringColor = $derived(cssModeColor(session.mode));

	const status = $derived(session.status);

	const statusLabel = $derived.by((): string => {
		const key = (
			status === 'idle'
				? 'focus.phase.idle'
				: status === 'running'
					? 'focus.phase.running'
					: status === 'paused'
						? 'focus.phase.paused'
						: 'focus.phase.completed'
		) as MessageKey;
		return t(locale, key);
	});

	function cssModeColor(mode: FocusMode): string {
		switch (mode) {
			case 'stopwatch':
				return 'var(--mode-stopwatch)';
			case 'flowtime':
				return 'var(--mode-flowtime)';
			case 'timeblock':
				return 'var(--mode-timeblock)';
			default:
				return 'var(--mode-pomodoro)';
		}
	}

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

	function reasonText(key: string): string {
		return t(locale, `focus.suggest.${key}` as MessageKey);
	}

	function applySuggestion() {
		app.selectMode(suggestion.mode);
	}

	function onKey(e: KeyboardEvent) {
		if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement || e.target instanceof HTMLSelectElement) {
			return;
		}
		if (e.code !== 'Space') return;
		e.preventDefault();
		if (status === 'idle' || status === 'completed') app.startFocus();
		else if (status === 'running') app.pauseFocus();
		else if (status === 'paused') app.resumeFocus();
	}
</script>

<svelte:window onkeydown={onKey} />

<section class="panel focus-screen" class:session-active={sessionActive}>
	{#if !sessionActive}
		<div class="panel-head">
			<h1>{t(locale, 'focus.title')}</h1>
		</div>

		<p class="banner banner-soft focus-honesty">{t(locale, 'focus.honesty')}</p>

		<div class="suggest-banner" class:locked={suggestion.locked}>
			<div class="suggest-main">
				<span class="suggest-kicker">{t(locale, 'focus.suggest.title')}</span>
				<div class="suggest-row">
					<span class="suggest-mode-icon" style="color: {cssModeColor(suggestion.mode)}">
						<ModeIcons mode={suggestion.mode} size={20} />
					</span>
					<div>
						<strong>{modeLabel(suggestion.mode)}</strong>
						<p class="muted suggest-reason">{reasonText(suggestion.reasonKey)}</p>
					</div>
				</div>
			</div>
			<button
				type="button"
				class="btn {suggestion.locked ? 'btn-ghost' : 'btn-primary'} suggest-cta"
				onclick={applySuggestion}
			>
				{suggestion.locked ? t(locale, 'focus.suggest.locked') : t(locale, 'focus.suggest.apply')}
			</button>
		</div>

		<div class="mode-scroll" role="group" aria-label="Focus mode">
			{#each modes as mode (mode)}
				{@const allowed = canUseMode(mode, app.tier)}
				<button
					type="button"
					class="mode-chip {mode}"
					class:active={app.selectedMode === mode && allowed}
					class:locked={!allowed}
					aria-pressed={app.selectedMode === mode && allowed}
					onclick={() => app.selectMode(mode)}
				>
					<span class="mode-chip-icon" class:active={app.selectedMode === mode && allowed}>
						<ModeIcons mode={mode} size={18} />
					</span>
					<span class="mode-chip-label">{modeLabel(mode)}</span>
					{#if !allowed}
						<span class="mode-chip-lock" aria-hidden="true">🔒</span>
					{/if}
				</button>
			{/each}
		</div>

		{#if app.upgradeTeaser === 'mode'}
			<p class="teaser">{t(locale, 'focus.upgradeTeaser')}</p>
		{/if}
	{/if}

	<div class="focus-hero" style="--ring-color: {ringColor};">
		<div class="timer-glow" aria-hidden="true"></div>
		<div
			class="timer-ring"
			class:running={status === 'running'}
			class:session-on={sessionActive}
			style="--progress: {progress}%; --ring-color: {ringColor};"
			aria-live="polite"
		>
			<div class="timer-inner">
				<span class="timer-mode-icon" style="color: {ringColor}">
					<ModeIcons mode={session.mode} size={24} />
				</span>
				<span class="timer-display">{formatMs(displayMs)}</span>
				<span class="timer-phase">
					<span class="timer-mode-dot" aria-hidden="true"></span>
					{modeLabel(session.mode)} · {statusLabel}
				</span>
			</div>
		</div>

		<div class="actions-row" class:expanded={!sessionActive} style="--action-color: {ringColor};">
			{#if status === 'idle'}
				<button class="btn btn-mode btn-start-wide" type="button" onclick={() => app.startFocus()}>
					{t(locale, 'focus.start')}
				</button>
			{:else if status === 'running'}
				<button
					class="btn btn-mode btn-circle"
					type="button"
					onclick={() => app.pauseFocus()}
					aria-label={t(locale, 'focus.pause')}
				>
					❚❚
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.skipFocus()}>
					{t(locale, 'focus.skip')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.completeFocus()}>
					{t(locale, 'focus.complete')}
				</button>
			{:else if status === 'paused'}
				<button
					class="btn btn-mode btn-circle"
					type="button"
					onclick={() => app.resumeFocus()}
					aria-label={t(locale, 'focus.resume')}
				>
					▶
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.skipFocus()}>
					{t(locale, 'focus.skip')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => app.completeFocus()}>
					{t(locale, 'focus.complete')}
				</button>
			{:else}
				<button class="btn btn-mode btn-start-wide" type="button" onclick={() => app.resetFocus()}>
					{t(locale, 'focus.reset')}
				</button>
			{/if}
		</div>
	</div>

	{#if !sessionActive || status === 'completed'}
		<div class="card focus-meta">
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
	{:else if session.taskId}
		{@const linked = app.activeTasks.find((x) => x.id === session.taskId)}
		{#if linked}
			<p class="linked-task-pill">
				<span class="muted">{t(locale, 'focus.linkTask')}:</span>
				<strong>{linked.title}</strong>
			</p>
		{/if}
	{/if}
</section>
