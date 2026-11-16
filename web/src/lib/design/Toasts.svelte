<script lang="ts">
	import { toast } from '$lib/stores/toast.svelte';
</script>

{#if toast.toasts.length > 0}
	<div class="toast-region">
		{#each toast.toasts as t (t.id)}
			<div class="toast" role="status">
				<span class="message">{t.message}</span>
				{#if t.actionLabel}
					<button
						class="action pressable"
						onclick={() => {
							t.onAction?.();
							toast.dismiss(t.id);
						}}
					>
						{t.actionLabel}
					</button>
				{/if}
			</div>
		{/each}
	</div>
{/if}

<style>
	.toast-region {
		position: fixed;
		left: 50%;
		bottom: calc(var(--tabbar-h) + var(--safe-b) + var(--space-4));
		transform: translateX(-50%);
		z-index: 60;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		align-items: center;
		pointer-events: none;
	}

	@media (min-width: 768px) {
		.toast-region {
			bottom: var(--space-6);
		}
	}

	.toast {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-3) var(--space-4);
		border-radius: var(--radius-md);
		background: var(--surface);
		border: 1px solid var(--border);
		color: var(--ink);
		font-size: var(--text-sm);
		font-weight: 550;
		box-shadow: var(--shadow-3);
		pointer-events: auto;
		animation: toast-in var(--dur-base) var(--ease-out-quint) both;
		max-width: min(480px, calc(100vw - var(--space-8)));
	}

	.message {
		flex: 1;
		min-width: 0;
	}

	.action {
		flex: none;
		border: none;
		background: none;
		color: var(--brand);
		font-weight: 700;
		font-size: var(--text-sm);
		cursor: pointer;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-sm);
	}

	.action:hover {
		background: var(--brand-softer);
	}

	@keyframes toast-in {
		from {
			opacity: 0;
			transform: translateY(12px);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.toast {
			animation: none;
		}
	}
</style>
