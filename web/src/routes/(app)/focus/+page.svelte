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

	<div class="controls">
		{#if focus.idle && !focus.waiting}
			{#if focus.mode === 'timeblock'}
				<button class="btn btn-ghost btn-icon pressable" aria-label="-15" onclick={() => focus.adjustBlock(-15)}>−15</button>
				<button class="btn btn-ghost btn-icon pressable" aria-label="-5" onclick={() => focus.adjustBlock(-5)}>−5</button>
			{/if}
			<button class="btn btn-primary pressable start" onclick={() => focus.start()}>
				<Icon name="play" size={20} />
				{t('focus.start')}
			</button>
			{#if focus.mode === 'timeblock'}
				<button class="btn btn-ghost btn-icon pressable" aria-label="+5" onclick={() => focus.adjustBlock(5)}>+5</button>
				<button class="btn btn-ghost btn-icon pressable" aria-label="+15" onclick={() => focus.adjustBlock(15)}>+15</button>
			{/if}
		{:else if focus.waiting}
			<button class="btn btn-primary pressable start" onclick={() => focus.start()}>
				<Icon name="play" size={20} />
				{t(focus.nextAfterHold !== 'work' ? 'focus.startBreak' : 'focus.startWork')}
			</button>
			{#if focus.nextAfterHold === 'work'}
				<button class="btn btn-outline pressable" onclick={() => focus.extendHold(5)}>
					+5 min
				</button>
			{/if}
		{:else if focus.running}
			<button class="btn btn-outline pressable" onclick={() => focus.pause()}>
				<Icon name="pause" size={20} />
				{t('focus.pause')}
			</button>
			{#if focus.mode === 'flowtime' && focus.breakSuggested}
				<button class="btn btn-soft pressable" onclick={() => focus.takeFlowBreak()}>
					🌊 {t('focus.takeBreak')}
				</button>
			{:else}
				<button class="btn btn-primary pressable" onclick={() => focus.complete()}>
					<Icon name="stop" size={20} />
					{t('focus.complete')}
				</button>
			{/if}
		{:else if focus.paused}
			<button class="btn btn-primary pressable" onclick={() => focus.resume()}>
				<Icon name="play" size={20} />
				{t('focus.resume')}
			</button>
			<button class="btn btn-outline pressable" onclick={() => focus.skip()}>
				<Icon name="skip" size={20} />
				{t('focus.skip')}
			</button>
		{/if}
	</div>

	<AdhdBreak />

	<Sheets />

	<CompanionCards />

	<p class="honesty">{t('focus.honesty')}</p>
</section>

<style>
	.focus {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-6);
		padding-top: var(--space-4);
	}

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
	}

	.controls {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
		align-items: center;
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
