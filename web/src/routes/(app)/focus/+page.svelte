<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import Icon from '$lib/design/Icon.svelte';
	import { FREE_MODES } from '$lib/domain/entities/types';
	import { suggestMode } from '$lib/domain/intelligence/modeSuggest';
	import { formatMs } from '$lib/format/time';
	import { liveElapsedMs, remainingMs } from '$lib/domain/focus/engine';

	const MODES = [
		{ id: 'pomodoro', key: 'focus.mode.pomodoro', color: 'var(--mode-pomodoro)' },
		{ id: 'flowtime', key: 'focus.mode.flowtime', color: 'var(--mode-flowtime)' },
		{ id: 'timeblock', key: 'focus.mode.timeblock', color: 'var(--mode-timeblock)' },
		{ id: 'stopwatch', key: 'focus.mode.stopwatch', color: 'var(--mode-stopwatch)' }
	] as const;

	const suggestion = suggestMode();
	const R = 120;
	const CIRC = 2 * Math.PI * R;

	let mode = $derived(app.session?.mode ?? app.selectedMode);
	let running = $derived(app.session?.status === 'running');
	let paused = $derived(app.session?.status === 'paused');
	let idle = $derived(!app.session || app.session.status === 'idle');
	let isFree = $derived((FREE_MODES as readonly string[]).includes(mode));

	let countdown = $derived(app.session?.targetMs != null);

	// Ring progress: countdown → remaining/target; count-up → elapsed/25min reference
	let progress = $derived.by(() => {
		const s = app.session;
		if (!s || s.status === 'idle') return 0;
		if (s.targetMs != null) {
			const rem = remainingMs(s, new Date()) ?? 0;
			return 1 - rem / s.targetMs;
		}
		const elapsed = liveElapsedMs(s, new Date());
		return Math.min(1, elapsed / (25 * 60 * 1000));
	});

	let modeColor = $derived(MODES.find((m) => m.id === mode)?.color ?? 'var(--brand)');
	let phaseLabel = $derived(
		idle ? t('focus.phase.idle') : running ? t('focus.phase.running') : paused ? t('focus.phase.paused') : ''
	);

	function selectMode(id: (typeof MODES)[number]['id']): void {
		if (!(FREE_MODES as readonly string[]).includes(id)) return;
		app.selectMode(id);
	}
</script>

<svelte:head>
	<title>{t('focus.title')} · Pepinillo</title>
</svelte:head>

<section class="focus mode-{mode} rise-in">
	<header class="modes" role="toolbar" aria-label={t('focus.title')}>
		{#each MODES as m (m.id)}
			{@const free = (FREE_MODES as readonly string[]).includes(m.id)}
			<button
				class="chip pressable"
				aria-pressed={mode === m.id}
				class:is-active={mode === m.id}
				class:is-locked={!free}
				disabled={!free}
				onclick={() => selectMode(m.id)}
				title={free ? t(m.key) : t('focus.mode.locked')}
			>
				{#if free}
					<span class="chip-dot" style="--chip-dot-color: {m.color}"></span>
				{:else}
					<Icon name="lock" size={14} />
				{/if}
				{t(m.key)}
			</button>
		{/each}
	</header>

	<div class="stage" class:is-running={running}>
		<svg class="ring" viewBox="0 0 280 280" role="img" aria-label={app.displayTime}>
			<circle class="ring-track" cx="140" cy="140" r={R} />
			<circle
				class="ring-fill"
				cx="140"
				cy="140"
				r={R}
				style="stroke-dasharray: {CIRC}; stroke-dashoffset: {CIRC * (1 - progress)}; stroke: {modeColor}"
			/>
		</svg>
		<div class="readout">
			<span class="phase">{phaseLabel}</span>
			<span class="time nums">{app.displayTime}</span>
		</div>
	</div>

	<div class="controls">
		{#if idle}
			<button class="btn btn-primary pressable start" onclick={() => app.start()}>
				<Icon name="play" size={20} />
				{t('focus.start')}
			</button>
		{:else if running}
			<button class="btn btn-outline pressable" onclick={() => app.pause()}>
				<Icon name="pause" size={20} />
				{t('focus.pause')}
			</button>
			<button class="btn btn-primary pressable" onclick={() => app.complete()}>
				<Icon name="stop" size={20} />
				{t('focus.complete')}
			</button>
		{:else if paused}
			<button class="btn btn-primary pressable" onclick={() => app.resume()}>
				<Icon name="play" size={20} />
				{t('focus.resume')}
			</button>
			<button class="btn btn-outline pressable" onclick={() => app.skip()}>
				<Icon name="skip" size={20} />
				{t('focus.skip')}
			</button>
		{/if}
	</div>

	<p class="honesty">{t('focus.honesty')}</p>
</section>

<style>
	.focus {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-8);
		padding-top: var(--space-4);
	}

	.modes {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: var(--space-2);
	}

	/* ---- The ring: the only glass moment on the web, mirroring the
		native Focus scene. Soft depth, mode-colored, no bounce. ---- */
	.stage {
		position: relative;
		width: min(72vw, 300px);
		aspect-ratio: 1;
		border-radius: 50%;
		background: var(--surface);
		border: 1px solid var(--border);
		box-shadow:
			var(--shadow-2),
			inset 0 1px 0 rgba(255, 255, 255, 0.35);
		backdrop-filter: blur(14px) saturate(1.3);
		-webkit-backdrop-filter: blur(14px) saturate(1.3);
	}

	.ring {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		transform: rotate(-90deg);
	}

	.ring-track {
		fill: none;
		stroke: var(--surface-sunken);
		stroke-width: 10;
	}

	.ring-fill {
		fill: none;
		stroke-width: 10;
		stroke-linecap: round;
		transition: stroke-dashoffset 260ms linear, stroke var(--dur-base) var(--ease-out-quint);
	}

	.readout {
		position: absolute;
		inset: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
	}

	.phase {
		color: var(--muted);
		font-size: var(--text-sm);
		font-weight: 600;
		letter-spacing: 0.02em;
	}

	.time {
		font-size: clamp(2.6rem, 8vw, 4rem);
		font-weight: 700;
		letter-spacing: var(--tracking-tight);
		font-variant-numeric: tabular-nums;
	}

	.controls {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
	}

	.start {
		min-width: 180px;
	}

	.honesty {
		color: var(--faint);
		font-size: var(--text-xs);
		max-width: 42ch;
		text-align: center;
	}
</style>
