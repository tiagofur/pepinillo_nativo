<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	const R = 120;
	const CIRC = 2 * Math.PI * R;

	let phaseKey = $derived<MessageKey>(
		focus.phase === 'work'
			? 'focus.phase.work'
			: focus.phase === 'shortBreak'
				? 'focus.phase.shortBreak'
				: focus.phase === 'longBreak'
					? 'focus.phase.longBreak'
					: 'focus.phase.idle'
	);
</script>

<div class="stage mode-stage" class:is-running={focus.running}>
	<svg class="ring" viewBox="0 0 280 280" role="img" aria-label={focus.displayTime}>
		<circle class="ring-track" cx="140" cy="140" r={R} />
		<circle
			class="ring-fill"
			cx="140"
			cy="140"
			r={R}
			style="stroke-dasharray: {CIRC}; stroke-dashoffset: {CIRC * (1 - focus.progress)}; stroke: {focus.phaseColor}"
		/>
	</svg>
	<div class="readout">
		<span class="phase">{t(phaseKey)}</span>
		<span class="time nums">{focus.displayTime}</span>
		{#if focus.mode === 'pomodoro' && focus.phase === 'work'}
			<span class="pips" aria-hidden="true">
				{#each { length: focus.beforeLongBreak } as _, i (i)}
					<span
						class="pip"
						class:done={i < focus.cycle.completedInCycle}
						class:current={i === focus.cycle.completedInCycle}
					></span>
				{/each}
			</span>
		{/if}
	</div>
</div>

<style>
	.stage {
		position: relative;
		width: min(72vw, 300px);
		aspect-ratio: 1;
		border-radius: 50%;
		background: var(--surface);
		border: 1px solid var(--border);
		box-shadow: var(--shadow-2);
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
		transition:
			stroke-dashoffset 260ms linear,
			stroke var(--dur-base) var(--ease-out-quint);
	}

	.readout {
		position: absolute;
		inset: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		padding: var(--space-8);
		text-align: center;
	}

	.phase {
		color: var(--muted);
		font-size: var(--text-sm);
		font-weight: 600;
		letter-spacing: 0.02em;
	}

	.time {
		font-size: clamp(2.4rem, 8vw, 3.8rem);
		font-weight: 700;
		letter-spacing: var(--tracking-tight);
		font-variant-numeric: tabular-nums;
	}

	.pips {
		display: flex;
		gap: 6px;
	}

	.pip {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--surface-sunken);
		border: 1px solid var(--border);
	}

	.pip.done {
		background: var(--mode-pomodoro);
		border-color: transparent;
	}

	.pip.current {
		box-shadow: var(--ring-glow);
		background: var(--mode-pomodoro-soft);
		border-color: var(--mode-pomodoro);
	}
</style>
