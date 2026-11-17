<script lang="ts">
	import { onMount } from 'svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import Icon from '$lib/design/Icon.svelte';
	import FocusRing from '$lib/features/focus/FocusRing.svelte';
	import Overlays from '$lib/features/focus/Overlays.svelte';
	import Sheets from '$lib/features/focus/Sheets.svelte';
	import CompanionCards from '$lib/features/focus/CompanionCards.svelte';
	import AdhdBreak from '$lib/features/focus/AdhdBreak.svelte';
	import PaneToolbar from '$lib/features/shell/PaneToolbar.svelte';
	import Segmented from '$lib/design/Segmented.svelte';
	import { FREE_MODES, type FocusMode } from '$lib/domain/entities/types';
	import type { MessageKey } from '$lib/i18n/messages';

	const MODES: { id: FocusMode; key: MessageKey; color: string }[] = [
		{ id: 'pomodoro', key: 'focus.mode.pomodoro', color: 'var(--mode-pomodoro)' },
		{ id: 'flowtime', key: 'focus.mode.flowtime', color: 'var(--mode-flowtime)' },
		{ id: 'timeblock', key: 'focus.mode.timeblock', color: 'var(--mode-timeblock)' },
		{ id: 'stopwatch', key: 'focus.mode.stopwatch', color: 'var(--mode-stopwatch)' }
	];

	// Mac parity: End Session is destructive and confirms before completing.
	let confirmEnd = $state(false);
	let confirmTimer: ReturnType<typeof setTimeout> | null = null;

	// The armed state never crosses a session boundary — any session
	// transition (start, skip, auto-advance, completion) disarms it.
	$effect(() => {
		void focus.session;
		confirmEnd = false;
		if (confirmTimer) clearTimeout(confirmTimer);
	});

	function onEnd(): void {
		if (confirmEnd) {
			confirmEnd = false;
			if (confirmTimer) clearTimeout(confirmTimer);
			focus.complete();
			return;
		}
		confirmEnd = true;
		confirmTimer = setTimeout(() => (confirmEnd = false), 3000);
	}

	onMount(() => {
		void focus.init();
		// Native Mac parity: Space starts/pauses the timer (⌘K capture lives globally).
		function onKeydown(e: KeyboardEvent): void {
			const target = e.target as HTMLElement | null;
			if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) return;
			if (e.code === 'Space') {
				e.preventDefault();
				if (focus.running) focus.pause();
				else if (focus.paused) focus.resume();
				else focus.start();
			}
		}
		function onStartRequest(): void {
			if (focus.running || focus.paused) return;
			focus.start();
		}
		window.addEventListener('keydown', onKeydown);
		window.addEventListener('pepinillo:focus-start', onStartRequest);
		return () => {
			window.removeEventListener('keydown', onKeydown);
			window.removeEventListener('pepinillo:focus-start', onStartRequest);
			if (confirmTimer) clearTimeout(confirmTimer);
		};
	});

	let waitingLabel = $derived(
		focus.nextAfterHold !== 'work' ? t('focus.waitingBreak') : t('focus.waitingWork')
	);
</script>

<svelte:head>
	<title>Focus · Pepinillo</title>
</svelte:head>

<section class="focus rise-in">
	<!-- PepinilloLiquidBackground: the 4 mode colors as drifting blobs —
		 60s ping-pong stepped every 2s (steps(30) alternate). Static under
		 reduced-motion; atmosphere 0.12 light / 0.22 dark (Mac rule). -->
	<div class="ambient" aria-hidden="true">
		<div class="blob p"></div>
		<div class="blob f"></div>
		<div class="blob t"></div>
		<div class="blob s"></div>
	</div>

	<div class="scene">
		<!-- Mac window toolbar: centered mode segmented, empty while a session runs -->
		<PaneToolbar title={t('focus.title')}>
			{#snippet center()}
				{#if focus.idle && !focus.waiting}
					<Segmented
						options={MODES.map((m) => ({
							id: m.id,
							label: t(m.key),
							disabled: !(FREE_MODES as readonly string[]).includes(m.id) || !focus.idle
						}))}
						value={focus.mode}
						onchange={(id) => focus.selectMode(id as FocusMode)}
					/>
				{/if}
			{/snippet}
		</PaneToolbar>

		<header class="modes" role="toolbar" aria-label={t('focus.title')}>
			{#each MODES as m (m.id)}
				{@const free = (FREE_MODES as readonly string[]).includes(m.id)}
				<button
					class="chip pressable"
					aria-pressed={focus.mode === m.id}
					class:is-active={focus.mode === m.id}
					class:is-locked={!free}
					disabled={!free || !focus.idle}
					onclick={() => focus.selectMode(m.id)}
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

		<Overlays />

		<FocusRing />

		{#if focus.waiting}
			<p class="waiting">{waitingLabel}</p>
		{/if}

		<div class="controls" style="--mode-hex: {focus.phaseColor}">
			{#if focus.idle && !focus.waiting}
				{#if focus.mode === 'timeblock'}
					<button class="stepper pressable" aria-label="-5 min" onclick={() => focus.adjustBlock(-5)}>−</button>
				{/if}
				<button class="primary-cta pressable" onclick={() => focus.start()}>
					<Icon name="play" size={18} />
					{t('focus.start')}
				</button>
				{#if focus.mode === 'timeblock'}
					<button class="stepper pressable" aria-label="+5 min" onclick={() => focus.adjustBlock(5)}>+</button>
				{/if}
			{:else if focus.waiting}
				<button class="primary-cta pressable" onclick={() => focus.start()}>
					<Icon name="play" size={18} />
					{t(focus.nextAfterHold !== 'work' ? 'focus.startBreak' : 'focus.startWork')}
				</button>
				{#if focus.nextAfterHold === 'work'}
					<button class="btn btn-outline pressable" onclick={() => focus.extendHold(5)}>
						+5 min
					</button>
				{/if}
			{:else if focus.running}
				<button class="primary-cta pressable" onclick={() => focus.pause()}>
					<Icon name="pause" size={18} />
					{t('focus.pause')}
				</button>
				{#if focus.mode === 'flowtime' && focus.breakSuggested}
					<button class="btn btn-soft pressable" onclick={() => focus.takeFlowBreak()}>
						🌊 {t('focus.takeBreak')}
					</button>
				{:else}
					<button class="btn btn-outline pressable" onclick={() => focus.skip()}>
						<Icon name="skip" size={16} />
						{t('focus.skip')}
					</button>
				{/if}
			<button class="end-cta pressable" class:armed={confirmEnd} aria-live="polite" onclick={onEnd}>
				{confirmEnd ? t('focus.endConfirm') : t('focus.complete')}
			</button>
		{:else if focus.paused}
			<button class="primary-cta pressable" onclick={() => focus.resume()}>
				<Icon name="play" size={18} />
				{t('focus.resume')}
			</button>
			<button class="btn btn-outline pressable" onclick={() => focus.skip()}>
				<Icon name="skip" size={16} />
				{t('focus.skip')}
			</button>
			<button class="end-cta pressable" class:armed={confirmEnd} aria-live="polite" onclick={onEnd}>
				{confirmEnd ? t('focus.endConfirm') : t('focus.complete')}
			</button>
		{/if}
		</div>

		<AdhdBreak />

		<Sheets />

		<CompanionCards />

		<p class="honesty">{t('focus.honesty')}</p>
	</div>
</section>

<style>
	.focus {
		position: relative;
	}

	.scene {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		padding-top: var(--space-4);
		position: relative;
		z-index: 1;
	}

	/* ---- Ambient mesh (PepinilloLiquidBackground web port) ----
	 * Bleed matches the shell's per-breakpoint content padding so the mesh
	 * reaches the window edges without creating horizontal overflow. */
	.ambient {
		position: absolute;
		inset: calc(-1 * var(--space-8)) calc(-1 * var(--space-8)) calc(-1 * var(--space-10));
		overflow: hidden;
		pointer-events: none;
		z-index: 0;
		opacity: 0.12;
	}

	@media (max-width: 1023px) {
		.ambient {
			inset: calc(-1 * var(--space-6)) calc(-1 * var(--space-5)) calc(-1 * var(--space-10));
		}
	}

	@media (max-width: 767px) {
		.ambient {
			inset: calc(-1 * var(--space-5)) calc(-1 * var(--space-4)) calc(-1 * var(--tabbar-h) - var(--safe-b) - var(--space-8));
		}
	}

	.blob {
		position: absolute;
		width: 46vmax;
		aspect-ratio: 1;
		border-radius: 50%;
		filter: blur(90px);
		will-change: transform;
	}

	.blob.p {
		background: radial-gradient(circle, var(--mode-pomodoro) 0%, transparent 70%);
		top: -18%;
		left: -12%;
		animation: drift-a 60s steps(30, end) infinite alternate;
	}

	.blob.f {
		background: radial-gradient(circle, var(--mode-flowtime) 0%, transparent 70%);
		top: 30%;
		right: -18%;
		animation: drift-b 60s steps(30, end) infinite alternate;
	}

	.blob.t {
		background: radial-gradient(circle, var(--mode-timeblock) 0%, transparent 70%);
		bottom: -20%;
		left: 15%;
		animation: drift-c 60s steps(30, end) infinite alternate;
	}

	.blob.s {
		background: radial-gradient(circle, var(--mode-stopwatch) 0%, transparent 70%);
		top: 45%;
		left: 35%;
		animation: drift-d 60s steps(30, end) infinite alternate;
	}

	@keyframes drift-a {
		from {
			transform: translate(0, 0) scale(1);
		}
		to {
			transform: translate(9vw, 7vh) scale(1.18);
		}
	}

	@keyframes drift-b {
		from {
			transform: translate(0, 0) scale(1.1);
		}
		to {
			transform: translate(-7vw, -5vh) scale(0.95);
		}
	}

	@keyframes drift-c {
		from {
			transform: translate(0, 0) scale(0.95);
		}
		to {
			transform: translate(6vw, -6vh) scale(1.15);
		}
	}

	@keyframes drift-d {
		from {
			transform: translate(0, 0) scale(1);
		}
		to {
			transform: translate(-8vw, 4vh) scale(1.12);
		}
	}

	:global([data-appearance='dark']) .ambient {
		opacity: 0.22;
	}

	@media (prefers-color-scheme: dark) {
		:global(:root:not([data-appearance='light'])) .ambient {
			opacity: 0.22;
		}
	}

	/* ---- Mode chips (<768px) ---- */
	.modes {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: var(--space-2);
	}

	/* ≥768px: the toolbar segmented replaces the chip row (Mac toolbar);
	 * below that the chips are the touch-friendly mode picker */
	@media (min-width: 768px) {
		.modes {
			display: none;
		}
	}

	.waiting {
		color: var(--muted);
		font-weight: 600;
		font-size: var(--text-sm);
		letter-spacing: var(--tracking-phase);
	}

	/* ---- Controls (Mac stage grammar) ---- */
	.controls {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
		align-items: center;
	}

	/* Primary capsule: interactive glass tinted with the mode color at 0.72,
	 * white label + specular stroke (primaryFocusActionGlass). Height floor
	 * keeps the touch target honest (34pt Mac, 44px on touch, 36 desktop). */
	.primary-cta {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-2);
		min-width: 200px;
		min-height: max(34px, var(--touch-target));
		padding: 0 var(--space-6);
		border: none;
		border-radius: var(--radius-pill);
		background: color-mix(in srgb, var(--mode-hex) 72%, transparent);
		backdrop-filter: blur(16px) saturate(1.3);
		-webkit-backdrop-filter: blur(16px) saturate(1.3);
		box-shadow:
			inset 0 0 0 1px rgba(255, 255, 255, 0.22),
			0 7px 14px color-mix(in srgb, var(--mode-hex) 35%, transparent);
		color: #ffffff;
		font-weight: 650;
		font-size: var(--text-base);
		cursor: pointer;
		transition:
			transform var(--dur-fast) var(--spring-snappy),
			opacity var(--dur-fast) var(--spring-snappy);
	}

	.primary-cta:not(:disabled):hover {
		opacity: 0.92;
	}

	.primary-cta:not(:disabled):active {
		transform: scale(0.98);
	}

	/* Duration steppers: 44px adaptive glass circles (44px glass circle) */
	.stepper {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: var(--touch-target);
		height: var(--touch-target);
		border: none;
		border-radius: 50%;
		background: var(--glass-bg);
		backdrop-filter: blur(16px) saturate(1.3);
		-webkit-backdrop-filter: blur(16px) saturate(1.3);
		box-shadow: inset 0 0 0 1px var(--glass-stroke);
		color: var(--ink);
		font-size: var(--text-md);
		font-weight: 600;
		cursor: pointer;
		transition:
			transform var(--dur-fast) var(--spring-snappy),
			opacity var(--dur-fast) var(--spring-snappy);
	}

	.stepper:active {
		transform: scale(0.94);
	}

	/* End Session: destructive, two-step confirm (confirmation dialog parity) */
	.end-cta {
		border: 1px solid transparent;
		background: transparent;
		color: var(--danger);
		font-weight: 600;
		font-size: var(--text-sm);
		padding: 0 var(--space-3);
		min-height: var(--touch-target);
		border-radius: var(--radius-pill);
		cursor: pointer;
	}

	.end-cta:hover {
		background: var(--danger-soft);
	}

	.end-cta.armed {
		background: var(--danger);
		color: #ffffff;
		font-weight: 650;
	}

	.honesty {
		color: var(--faint);
		font-size: var(--text-xs);
		max-width: 42ch;
		text-align: center;
	}
</style>
