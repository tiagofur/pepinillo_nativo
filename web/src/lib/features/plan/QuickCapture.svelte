<script lang="ts">
	/**
	 * Command palette (⌘K / Ctrl+K) — Google-style: fuzzy-filtered commands
	 * (navigate, actions) + task capture, keyboard-first.
	 * Global: mounted in the app shell.
	 */
	import { onMount, tick } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { toast } from '$lib/stores/toast.svelte';
	import { t, currentLocale } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { parseNaturalDateSuffix } from '$lib/domain/tasks/natural-date';
	import { derivedLegacyFlag, formatDueShort } from '$lib/domain/tasks/plan';
	import Icon from '$lib/design/Icon.svelte';

	interface Command {
		id: string;
		label: string;
		hint?: string;
		key: MessageKey | null;
		run: () => void | Promise<void>;
	}

	let open = $state(false);
	let value = $state('');
	let activeIndex = $state(0);
	let inputEl = $state<HTMLInputElement | null>(null);
	let listEl = $state<HTMLDivElement | null>(null);

	async function goto(path: string): Promise<void> {
		const { goto: nav } = await import('$app/navigation');
		await nav(path);
	}

	async function toggleAppearance(): Promise<void> {
		const next = document.documentElement.getAttribute('data-appearance') === 'dark' ? 'light' : 'dark';
		app.setAppearance(next);
		toast.show(next === 'dark' ? '🌙 Dark' : '☀️ Light');
	}

	async function startFocusNow(): Promise<void> {
		await goto('/focus');
		await tick();
		// start after navigation settles
		setTimeout(() => {
			window.dispatchEvent(new CustomEvent('pepinillo:focus-start'));
		}, 300);
	}

	const COMMANDS: Command[] = [
		{ id: 'nav-focus', label: 'Focus', hint: '⌘1', key: 'palette.focus', run: () => void goto('/focus') },
		{ id: 'nav-plan', label: 'Plan', hint: '⌘2', key: 'palette.plan', run: () => void goto('/plan') },
		{ id: 'nav-dash', label: 'Dashboard', hint: '⌘3', key: 'palette.dashboard', run: () => void goto('/dashboard') },
		{ id: 'nav-account', label: 'Account', key: 'nav.account', run: () => void goto('/account') },
		{ id: 'nav-guides', label: 'Guides', key: 'landing.nav.guides', run: () => void goto('/guides') },
		{ id: 'nav-upgrade', label: 'Pricing', key: 'landing.nav.pricing', run: () => void goto('/upgrade') },
		{ id: 'act-start', label: 'Start focus session', hint: 'Space', key: 'palette.startFocus', run: startFocusNow },
		{ id: 'act-theme', label: 'Toggle light / dark', key: 'palette.toggleTheme', run: toggleAppearance }
	];

	let filteredCommands = $derived.by(() => {
		const q = value.trim().toLowerCase();
		if (!q) return COMMANDS;
		return COMMANDS.filter((c) => c.label.toLowerCase().includes(q));
	});

	let captureEntry = $derived(value.trim().length > 0 ? { id: '__capture', label: value.trim() } : null);
	let results = $derived.by(() => {
		const list: { id: string; label: string; kind: 'command' | 'capture'; command?: Command }[] = [];
		if (captureEntry) list.push({ id: captureEntry.id, label: captureEntry.label, kind: 'capture' });
		for (const c of filteredCommands) list.push({ id: c.id, label: c.label, kind: 'command', command: c });
		return list;
	});

	$effect(() => {
		activeIndex = 0;
	});

	function onKeydown(e: KeyboardEvent): void {
		if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
			e.preventDefault();
			open = !open;
			if (open) {
				value = '';
				setTimeout(() => inputEl?.focus(), 50);
			}
			return;
		}
		if (!open) return;
		if (e.key === 'Escape') {
			open = false;
			return;
		}
		if (e.key === 'ArrowDown') {
			e.preventDefault();
			activeIndex = Math.min(results.length - 1, activeIndex + 1);
			scrollActive();
		} else if (e.key === 'ArrowUp') {
			e.preventDefault();
			activeIndex = Math.max(0, activeIndex - 1);
			scrollActive();
		} else if (e.key === 'Enter') {
			e.preventDefault();
			void runResult(results[activeIndex]);
		}
	}

	function scrollActive(): void {
		tick().then(() => {
			listEl?.querySelector('.result.is-active')?.scrollIntoView({ block: 'nearest' });
		});
	}

	async function runResult(result: (typeof results)[number] | undefined): Promise<void> {
		if (!result) return;
		if (result.kind === 'capture') {
			// #994: a natural-language date at the end of the capture plans the
			// task and leaves the title; «Quitar fecha» on the toast restores
			// the original text.
			const now = new Date();
			const parsed = parseNaturalDateSuffix(result.label, now);
			const overrides = parsed.plannedDate
				? { plannedDate: parsed.plannedDate, scheduledForToday: derivedLegacyFlag(parsed.plannedDate, now) }
				: {};
			const task = await plan.addTask(parsed.title, overrides);
			if (task) {
				if (parsed.plannedDate) {
					const originalTitle = result.label;
					toast.show(
						t('plan.taskParsedBanner', {
							title: parsed.title,
							date: formatDueShort(parsed.plannedDate, currentLocale())
						}),
						{
							actionLabel: t('plan.removeDate'),
							onAction: () =>
								void plan.updateTask(task.id, {
									plannedDate: null,
									scheduledForToday: false,
									title: originalTitle
								})
						}
					);
				} else {
					toast.show(t('quickCapture.captured', { title: task.title }));
				}
				value = '';
				plan.capNotice = false;
				open = false;
			}
			return;
		}
		open = false;
		await result.command?.run();
	}

	onMount(() => {
		window.addEventListener('keydown', onKeydown);
		return () => window.removeEventListener('keydown', onKeydown);
	});
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="qc-backdrop" onclick={() => (open = false)}>
		<!-- Spotlight-style bar (Mac Quick Capture: material r16, top 22%) -->
		<div class="qc" role="dialog" aria-modal="true" aria-label={t('quickCapture.title')}>
			<span class="qc-icon" aria-hidden="true"><Icon name="plus" size={18} /></span>
			<input
				bind:this={inputEl}
				bind:value
				class="qc-input"
				placeholder={t('palette.placeholder')}
				aria-label={t('palette.placeholder')}
			/>
			<kbd class="esc">esc</kbd>
		</div>
		<div class="results" bind:this={listEl}>
			{#each results as result, i (result.id)}
				<button
					class="result pressable"
					class:is-active={i === activeIndex}
					onclick={() => void runResult(result)}
					onmouseenter={() => (activeIndex = i)}
				>
					{#if result.kind === 'capture'}
						<span class="r-icon">＋</span>
						<span class="r-label">{t('palette.addTask')}: <strong>{result.label}</strong></span>
						<span class="r-hint">↵</span>
					{:else}
						<span class="r-icon">›</span>
						<span class="r-label">{result.label}</span>
						{#if result.command?.hint}
							<kbd class="r-hint">{result.command.hint}</kbd>
						{/if}
					{/if}
				</button>
			{/each}
			{#if results.length === 0}
				<p class="empty muted">{t('palette.empty')}</p>
			{/if}
		</div>
		{#if app.tier === 'free'}
			<p class="qc-cap" class:is-blocked={plan.capNotice} aria-live="polite">
				🔒 {t('plan.capCounter', { n: plan.activeCount })}{#if plan.capNotice}
					— {t('plan.capInline')}
				{/if}
			</p>
		{/if}
	</div>
{/if}

<style>
	.qc-backdrop {
		position: fixed;
		inset: 0;
		z-index: 75;
		background: rgba(0, 0, 0, 0.35);
		display: flex;
		flex-direction: column;
		align-items: center;
		padding-top: min(22vh, 200px); /* Mac Quick Capture: 22% from top */
		gap: var(--space-3);
	}

	.qc {
		width: min(520px, calc(100vw - var(--space-8)));
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		background: var(--material-bg);
		backdrop-filter: blur(20px) saturate(1.4);
		-webkit-backdrop-filter: blur(20px) saturate(1.4);
		border: 1px solid var(--hairline);
		border-radius: 16px; /* Mac Quick Capture panel radius */
		box-shadow: var(--shadow-3);
		animation: rise-in var(--dur-base) var(--ease-out-quint) both;
	}

	.qc-icon {
		display: inline-flex;
		color: var(--brand);
	}

	.qc-input {
		flex: 1;
		border: none;
		background: transparent;
		min-height: 44px;
		font-size: var(--text-md);
	}

	.qc-input:focus {
		outline: none;
		box-shadow: none;
	}

	.esc {
		font-size: var(--text-2xs); /* 11px floor */
		color: var(--faint);
		border: 1px solid var(--border);
		border-radius: 6px;
		padding: 2px 6px;
	}

	.results {
		width: min(520px, calc(100vw - var(--space-8)));
		max-height: 320px;
		overflow-y: auto;
		padding: var(--space-2);
		background: var(--material-bg);
		backdrop-filter: blur(20px) saturate(1.4);
		-webkit-backdrop-filter: blur(20px) saturate(1.4);
		border: 1px solid var(--hairline);
		border-radius: 16px;
		box-shadow: var(--shadow-3);
		animation: rise-in var(--dur-base) var(--ease-out-quint) both;
	}

	.result {
		width: 100%;
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 44px;
		padding: 0 var(--space-3);
		border: none;
		background: none;
		border-radius: var(--radius-md);
		cursor: pointer;
		text-align: start;
		color: var(--ink-secondary);
		font-size: var(--text-sm);
	}

	.result.is-active {
		background: var(--brand-soft);
		color: var(--ink);
	}

	.r-icon {
		color: var(--brand);
		font-weight: 700;
		width: 18px;
		flex: none;
	}

	.r-label {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.r-hint {
		font-size: var(--text-2xs); /* 11px floor */
		color: var(--faint);
		border: 1px solid var(--border);
		border-radius: 6px;
		padding: 1px 6px;
		flex: none;
	}

	.empty {
		padding: var(--space-4);
		text-align: center;
		font-size: var(--text-sm);
		color: var(--muted);
	}

	.qc-cap {
		color: #ffd7d2;
		font-size: var(--text-sm);
		font-weight: 600;
		background: rgba(0, 0, 0, 0.45);
		border-radius: var(--radius-pill);
		padding: var(--space-2) var(--space-4);
	}

	.qc-cap.is-blocked {
		color: var(--mode-pomodoro);
		font-weight: 600;
	}
</style>
