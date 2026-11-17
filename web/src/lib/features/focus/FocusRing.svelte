<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import Icon from '$lib/design/Icon.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	let phaseKey = $derived<MessageKey>(
		focus.phase === 'work'
			? 'focus.phase.work'
			: focus.phase === 'shortBreak'
				? 'focus.phase.shortBreak'
				: focus.phase === 'longBreak'
					? 'focus.phase.longBreak'
					: 'focus.phase.idle'
	);

	/** Count-up modes at idle show the dashed [4,10] overlay (Mac TimerCircleView). */
	let dashedIdle = $derived(
		(focus.mode === 'flowtime' || focus.mode === 'stopwatch') && focus.idle && !focus.waiting
	);

	/** Progress 0–1 as a conic stop; idle count-up floors at 4% like Mac. */
	let arcP = $derived(
		focus.idle && !focus.waiting && (focus.mode === 'flowtime' || focus.mode === 'stopwatch')
			? 0.04
			: focus.progress
	);
</script>

<div class="stage" style="--mode-hex: {focus.phaseColor}; --p: {arcP}">
	<div class="ring" role="img" aria-label={focus.displayTime}>
		<div class="layer track"></div>
		{#if dashedIdle}
			<div class="layer dashed"></div>
		{/if}
		<div class="layer clip">
			<div class="layer arc"></div>
		</div>
		<div class="center">
			<span class="mode-icon" class:breathing={focus.running} aria-hidden="true">
				<Icon name="focus" size={30} />
			</span>
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
	<p class="phase">{t(phaseKey)}</p>
</div>

<style>
	/* Mac TimerCircleView: ring floats on the ambient stage — no card.
	 * stroke 13, track = mode color at 18%, arc = angular gradient
	 * [0.4c, c, 0.4c] from 12 o'clock, dashed [4,10] idle overlay. */
	.stage {
		--stroke: 13px;
		--ring-size: min(360px, max(260px, calc(100dvh - 340px)));
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
	}

	.ring {
		position: relative;
		width: var(--ring-size);
		aspect-ratio: 1;
	}

	.layer {
		position: absolute;
		inset: 0;
		border-radius: 50%;
		-webkit-mask: radial-gradient(
			farthest-side,
			transparent calc(100% - var(--stroke) - 1px),
			#000 calc(100% - var(--stroke))
		);
		mask: radial-gradient(
			farthest-side,
			transparent calc(100% - var(--stroke) - 1px),
			#000 calc(100% - var(--stroke))
		);
	}

	.track {
		background: color-mix(in srgb, var(--mode-hex) 18%, transparent);
	}

	/* Count-up idle hint: dashes ≈ SVG [4,10] on a 173.5pt radius (1.32° / 4.62°) */
	.dashed {
		background: repeating-conic-gradient(
			from -90deg,
			color-mix(in srgb, var(--mode-hex) 30%, transparent) 0deg 1.32deg,
			transparent 1.32deg 4.62deg
		);
	}

	/* Progress clip: an opaque conic sector growing clockwise from 12 o'clock */
	.clip {
		background: none;
		-webkit-mask: conic-gradient(from -90deg, #000 calc(var(--p) * 360deg), transparent 0deg);
		mask: conic-gradient(from -90deg, #000 calc(var(--p) * 360deg), transparent 0deg);
	}

	.arc {
		background: conic-gradient(
			from -90deg,
			color-mix(in srgb, var(--mode-hex) 40%, transparent) 0deg,
			var(--mode-hex) 180deg,
			color-mix(in srgb, var(--mode-hex) 40%, transparent) 360deg
		);
	}

	.center {
		position: absolute;
		inset: 0;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		text-align: center;
	}

	.mode-icon {
		color: var(--muted);
		display: inline-flex;
	}

	.mode-icon.breathing {
		color: var(--mode-hex);
		animation: breathe 2s var(--ease-out-quint) infinite alternate;
	}

	.time {
		font-family: var(--font-rounded);
		font-variant-numeric: tabular-nums;
		font-feature-settings: 'tnum' 1;
		font-size: clamp(56px, calc(var(--ring-size) * 0.22), 84px);
		font-weight: 600;
		line-height: 1;
		letter-spacing: var(--tracking-tight);
		color: var(--ink);
	}

	.pips {
		display: flex;
		gap: 6px;
	}

	.pip {
		width: 7px;
		height: 7px;
		border-radius: 50%;
		background: color-mix(in srgb, var(--ink) 15%, transparent);
	}

	.pip.done {
		background: var(--mode-pomodoro);
	}

	.pip.current {
		background: color-mix(in srgb, var(--mode-pomodoro) 25%, transparent);
		box-shadow: 0 0 0 2px color-mix(in srgb, var(--mode-pomodoro) 30%, transparent);
	}

	/* Phase label under the ring: subheadline semibold, tracking 1.1 (Mac) */
	.phase {
		margin: 0;
		color: var(--muted);
		font-size: var(--text-sm);
		font-weight: 650;
		letter-spacing: var(--tracking-phase);
		text-transform: uppercase;
	}

	@keyframes breathe {
		from {
			transform: scale(1);
		}
		to {
			transform: scale(1.06);
		}
	}

	/* Phones: fit small viewports — the 260px floor is not forced (UX brief) */
	@media (max-width: 420px) {
		.stage {
			--ring-size: min(88vw, 320px);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.mode-icon.breathing {
			animation: none;
		}
	}
</style>
