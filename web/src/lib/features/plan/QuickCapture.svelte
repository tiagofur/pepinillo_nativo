<script lang="ts">
	/**
	 * Quick Capture palette (⌘K / Ctrl+K) — native Quick Capture parity.
	 * Global: mounted in the app shell; captures to Inbox from anywhere.
	 */
	import { onMount } from 'svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { t } from '$lib/i18n/i18n.svelte';

	let open = $state(false);
	let value = $state('');
	let inputEl = $state<HTMLInputElement | null>(null);

	function onKeydown(e: KeyboardEvent): void {
		if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
			e.preventDefault();
			open = !open;
			if (open) setTimeout(() => inputEl?.focus(), 50);
			return;
		}
		if (open && e.key === 'Escape') {
			open = false;
		}
	}

	onMount(() => {
		window.addEventListener('keydown', onKeydown);
		return () => window.removeEventListener('keydown', onKeydown);
	});

	async function submit(): Promise<void> {
		const task = await plan.addTask(value);
		if (task) {
			value = '';
			plan.capNotice = false;
			open = false;
		}
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="qc-backdrop" onclick={() => (open = false)}>
		<div class="qc card" role="dialog" aria-modal="true" aria-label={t('quickCapture.title')}>
			<span class="qc-icon" aria-hidden="true">⚡</span>
			<input
				bind:this={inputEl}
				bind:value
				class="qc-input"
				placeholder={t('quickCapture.placeholder')}
				onkeydown={(e) => e.key === 'Enter' && submit()}
			/>
			<button class="btn btn-primary pressable" onclick={submit}>{t('plan.add')}</button>
		</div>
		{#if plan.capNotice}
			<p class="qc-cap">🔒 {t('plan.capBlocked')}</p>
		{/if}
		<p class="qc-hint">{t('quickCapture.hint')}</p>
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
		justify-content: flex-start;
		padding-top: min(18vh, 160px);
		gap: var(--space-3);
	}

	.qc {
		width: min(560px, calc(100vw - var(--space-8)));
		display: flex;
		align-items: center;
		gap: var(--space-3);
		padding: var(--space-3) var(--space-4);
		animation: rise-in var(--dur-base) var(--ease-out-quint) both;
	}

	.qc-icon {
		font-size: 20px;
	}

	.qc-input {
		flex: 1;
		border: none;
		background: transparent;
		min-height: 44px;
	}

	.qc-input:focus {
		outline: none;
		box-shadow: none;
	}

	.qc-hint {
		color: rgba(255, 255, 255, 0.75);
		font-size: var(--text-xs);
	}

	.qc-cap {
		color: #ffd7d2;
		font-size: var(--text-sm);
		font-weight: 600;
		background: rgba(0, 0, 0, 0.45);
		border-radius: var(--radius-pill);
		padding: var(--space-2) var(--space-4);
	}
</style>
