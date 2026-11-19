<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import Icon from '$lib/design/Icon.svelte';

	/** Phase label — Mac FocusPhase.displayName: the cycle position is
	 * expressed ONCE, here ("Enfoque 2/4"); the numeric counter was removed
	 * from the ring center (#789). Flowtime/Stopwatch name their work phase
	 * by mode; a flowtime break is its own "Break" phase (flowBreak). */
	let phaseLabel = $derived.by(() => {
		if (focus.idle && !focus.waiting) return t('focus.phase.idle');
		if (focus.paused) return t('focus.phase.paused');
		const pending = focus.waiting ? focus.nextAfterHold : focus.phase;
		if (pending === 'work') {
			if (focus.mode === 'pomodoro')
				return t('focus.phase.workNumbered', {
					n: focus.cycle.pomodoroNumber,
					total: focus.beforeLongBreak
				});
			if (focus.mode === 'flowtime') return t('focus.phase.flow');
			if (focus.mode === 'stopwatch') return t('focus.phase.freeform');
			return t('focus.phase.block');
		}
		if (pending === 'shortBreak')
			return focus.mode === 'flowtime' ? t('focus.phase.flowBreak') : t('focus.phase.shortBreak');
		return t('focus.phase.longBreak');
	});

	let countUp = $derived(focus.mode === 'flowtime' || focus.mode === 'stopwatch');

	/** Mac TimerCircleView: dashed [4,10] overlay whenever the count-up ring
	 * is not ticking (idle, hold, paused); countdown idle/hold shows the
	 * full ring of the pending phase instead (FocusView.swift:1021-1031). */
	let dashed = $derived(countUp && !focus.running);

	/** Store-derived display arc (ringProgress): countdown depletes from
	 * full; count-up fills its 60-minute cycle while running. `null` → no
	 * arc layer at all. */
	let arcP = $derived(focus.ringProgress ?? 0);
	let hasArc = $derived(focus.ringProgress !== null);

	/** Mac tap-to-pause: the ring toggles pause while a session is live. */
	let interactive = $derived(focus.running || focus.paused);
	function onRingTap(): void {
		if (focus.running) focus.pause();
		else if (focus.paused) focus.resume();
	}
	function onRingKey(e: KeyboardEvent): void {
		if (e.code === 'Enter' || e.code === 'Space') {
			e.preventDefault();
			onRingTap();
		}
	}

	/** Native accessibility value: digits + percent remaining/complete. */
	let ariaLabel = $derived.by(() => {
		if (!interactive || focus.ringProgress == null) return focus.displayTime;
		const pct = Math.round(focus.ringProgress * 100);
		const tail = countUp ? t('focus.a11y.complete', { pct }) : t('focus.a11y.remaining', { pct });
		return `${focus.displayTime}, ${tail}`;
	});
</script>

<div class="stage" style="--mode-hex: {focus.phaseColor}; --p: {arcP}">
	<div
		class="ring"
		role={interactive ? 'button' : 'img'}
		tabindex={interactive ? 0 : undefined}
		aria-label={ariaLabel}
		class:interactive
		onclick={interactive ? onRingTap : undefined}
		onkeydown={interactive ? onRingKey : undefined}
	>
		<div class="layer track"></div>
		{#if dashed}
			<div class="layer dashed"></div>
		{/if}
		{#if hasArc}
			<div class="layer clip">
				<div class="layer arc"></div>
			</div>
		{/if}
		<div class="center">
			<span class="mode-icon" class:breathing={focus.running} aria-hidden="true">
				<Icon name="focus" />
			</span>
			<span class="time nums">{focus.displayTime}</span>
		</div>
	</div>
	<p class="phase">{phaseLabel}</p>
</div>

<style>
	/* Mac TimerCircleView: ring floats on the ambient stage — no card.
	 * stroke 13, track = mode color at 18%, arc = angular gradient
	 * [0.4c, c, 0.4c] from 12 o'clock, dashed [4,10] count-up overlay.
	 * Countdown arcs start FULL and deplete anchored at 12 o'clock
	 * (rotationEffect(-90) native ≡ conic from 0deg here). */
	.stage {
		--stroke: 13px;
		--ring-size: min(360px, max(260px, calc(100dvh - 340px)));
		--digit-px: clamp(52px, calc(var(--ring-size) * 0.2), 72px);
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

	.ring.interactive {
		cursor: pointer;
	}

	.ring.interactive:focus-visible {
		outline: 2px solid color-mix(in srgb, var(--mode-hex) 60%, transparent);
		outline-offset: 8px;
		border-radius: 50%;
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

	/* Count-up idle hint: dashes ≈ SVG [4,10] on a 173.5pt radius (1.32° / 4.62°).
	 * CSS conic 0deg is already 12 o'clock — no rotation offset (unlike SVG). */
	.dashed {
		background: repeating-conic-gradient(
			from 0deg,
			color-mix(in srgb, var(--mode-hex) 30%, transparent) 0deg 1.32deg,
			transparent 1.32deg 4.62deg
		);
	}

	/* Progress clip: an opaque conic sector growing clockwise from 12 o'clock.
	 * The sector length is the REMAINING fraction for countdown (starts full,
	 * shrinks back to 12) or the in-cycle fraction for count-up. */
	.clip {
		background: none;
		-webkit-mask: conic-gradient(from 0deg, #000 calc(var(--p) * 360deg), transparent 0deg);
		mask: conic-gradient(from 0deg, #000 calc(var(--p) * 360deg), transparent 0deg);
	}

	.arc {
		background: conic-gradient(
			from 0deg,
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

	/* Mac: the icon inherits the digit scale (28/84 ≈ 0.33 ratio, floor 28)
	 * so the composition stays proportional at every ring size. */
	.mode-icon :global(svg) {
		width: max(28px, calc(var(--digit-px) * 0.33));
		height: max(28px, calc(var(--digit-px) * 0.33));
	}

	.mode-icon.breathing {
		color: var(--mode-hex);
		animation: breathe 2s var(--ease-out-quint) infinite alternate;
	}

	.time {
		font-family: var(--font-rounded);
		font-variant-numeric: tabular-nums;
		font-feature-settings: 'tnum' 1;
		/* Mac digits: 72pt at the 360pt reference ring (84pt only above 380pt,
		 * which the 360px cap never reaches — 0.2 × 360 = 72 exact) */
		font-size: var(--digit-px);
		font-weight: 600;
		line-height: 1;
		letter-spacing: var(--tracking-tight);
		color: var(--ink);
	}

	/* Phase label under the ring: subheadline semibold, tracking 1.1 — no
	 * uppercase transform (Mac renders the label as written). */
	.phase {
		margin: 0;
		color: var(--muted);
		font-size: var(--text-sm);
		font-weight: 650;
		letter-spacing: var(--tracking-phase);
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
