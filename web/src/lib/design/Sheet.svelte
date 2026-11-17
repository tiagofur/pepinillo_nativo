<script lang="ts">
	import type { Snippet } from 'svelte';
	/**
	 * Adaptive sheet: bottom sheet on touch/mobile, centered card on desktop.
	 * Backdrop tap dismisses; Escape closes (global); focus-safe and touch-first.
	 */
	let {
		open,
		onclose,
		title,
		children
	}: { open: boolean; onclose: () => void; title: string; children: Snippet } = $props();

	function onKeydown(e: KeyboardEvent): void {
		if (open && e.key === 'Escape') onclose();
	}
</script>

<svelte:window onkeydown={onKeydown} />

{#if open}
	<!-- a11y waiver: keyboard users close via global Escape and the Close button;
			backdrop tap is a pointer-only convenience. -->
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="backdrop" onclick={onclose} role="presentation">
		<div
			class="sheet"
			role="dialog"
			aria-modal="true"
			aria-label={title}
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
		>
			<header class="head">
				<h2>{title}</h2>
				<button class="close btn-icon pressable" aria-label="Close" onclick={onclose}>✕</button>
			</header>
			{@render children()}
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		z-index: 70;
		background: rgba(0, 0, 0, 0.35);
		display: flex;
		align-items: flex-end;
		justify-content: center;
		animation: fade var(--dur-base) var(--ease-out-quint) both;
	}

	.sheet {
		width: min(520px, 100%);
		max-height: 82dvh;
		overflow-y: auto;
		background: var(--surface);
		border: 1px solid var(--border);
		box-shadow: var(--shadow-3);
		border-radius: var(--radius-xl) var(--radius-xl) 0 0;
		padding: var(--space-5) var(--space-5) calc(var(--space-6) + var(--safe-b));
		animation: sheet-up var(--dur-base) var(--ease-out-quint) both;
	}

	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: var(--space-4);
	}

	h2 {
		font-size: var(--text-md);
	}

	.close {
		background: var(--surface-alt);
		border: none;
		color: var(--ink-secondary);
		cursor: pointer;
	}

	@media (min-width: 768px) {
		.backdrop {
			align-items: center;
		}

		.sheet {
			border-radius: var(--radius-xl); /* Mac sheet corner 28 */
			padding-bottom: var(--space-6);
		}
	}

	@keyframes fade {
		from {
			opacity: 0;
		}
	}

	@keyframes sheet-up {
		from {
			opacity: 0;
			transform: translateY(24px);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.backdrop,
		.sheet {
			animation: none;
		}
	}
</style>
