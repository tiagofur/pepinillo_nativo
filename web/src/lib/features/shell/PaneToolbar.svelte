<script lang="ts">
	import type { Snippet } from 'svelte';
	/**
	 * Mac-style per-pane window toolbar: title at the left, optional centered
	 * content (Focus mode segmented), optional right actions. Sticks to the
	 * top of the content column with a hairline rule, like the Mac window
	 * chrome. On phones it collapses to a compact top bar (title + actions).
	 */
	let {
		title,
		center,
		right
	}: { title: string; center?: Snippet; right?: Snippet } = $props();
</script>

<header class="pane-toolbar">
	<div class="pt-side pt-left">
		<h1 class="pt-title">{title}</h1>
	</div>
	<div class="pt-center">
		{#if center}{@render center()}{/if}
	</div>
	<div class="pt-side pt-right">
		{#if right}{@render right()}{/if}
	</div>
</header>

<style>
	.pane-toolbar {
		position: sticky;
		top: 0; /* sticky insets are scrollport-relative — the negative margin
				 above already seats the toolbar flush with the viewport top */
		z-index: 30;
		width: 100%;
		display: grid;
		grid-template-columns: 1fr auto 1fr;
		align-items: center;
		gap: var(--space-3);
		min-height: 52px;
		margin: calc(-1 * var(--space-8)) calc(-1 * var(--space-8)) var(--space-5);
		padding: 0 var(--space-5);
		background: var(--bg);
		border-bottom: 1px solid var(--hairline);
	}

	.pt-side {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-width: 0;
	}

	.pt-right {
		justify-content: flex-end;
	}

	.pt-title {
		font-size: var(--text-md);
		font-weight: 700;
		letter-spacing: var(--tracking-tight);
		margin: 0;
		white-space: nowrap;
	}

	.pt-center :global(.segmented) {
		background: var(--surface);
	}

	.pt-right :global(.pt-btn) {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: var(--space-1);
		min-width: 30px;
		min-height: 30px;
		padding: 0 var(--space-2);
		border: none;
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--ink-secondary);
		cursor: pointer;
		transition:
			background-color var(--dur-fast) var(--ease-out-quint),
			color var(--dur-fast) var(--ease-out-quint);
	}

	.pt-right :global(.pt-btn:hover) {
		background: var(--surface-alt);
		color: var(--ink);
	}

	.pt-right :global(.pt-btn.is-on) {
		background: var(--brand-soft);
		color: var(--brand);
	}

	.pt-right :global(.pt-group) {
		display: inline-flex;
		align-items: center;
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius-sm);
		overflow: hidden;
	}

	.pt-right :global(.pt-group .pt-btn) {
		border-radius: 0;
	}

	.pt-right :global(.pt-group .pt-btn + .pt-btn) {
		border-left: 1px solid var(--hairline);
	}

	.pt-right :global(.pt-search) {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-width: 180px;
		max-width: 260px;
		min-height: 30px;
		padding: 0 var(--space-3);
		border: 1px solid var(--border);
		border-radius: var(--radius-sm);
		background: var(--surface);
		color: var(--muted);
	}

	.pt-right :global(.pt-search:focus-within) {
		border-color: var(--brand);
		box-shadow: 0 0 0 3px var(--brand-softer);
	}

	.pt-right :global(.pt-search input) {
		flex: 1;
		min-width: 0;
		border: none;
		background: transparent;
		color: var(--ink);
		font-size: var(--text-sm);
	}

	.pt-right :global(.pt-search input:focus) {
		outline: none;
		box-shadow: none;
	}

	/* Tablet: cancel the shell's 24px content padding (must precede the
	 * phone block so phones keep their own tighter margin) */
	@media (max-width: 1023px) {
		.pane-toolbar {
			margin: calc(-1 * var(--space-6)) calc(-1 * var(--space-5)) var(--space-5);
		}
	}

	/* Phones: compact top bar — title + one secondary action; the search
	 * field flexes so narrow viewports never squeeze or overflow */
	@media (max-width: 767px) {
		.pane-toolbar {
			grid-template-columns: auto 1fr;
			min-height: 44px;
			margin: calc(-1 * var(--space-5)) calc(-1 * var(--space-4)) var(--space-4);
			padding: 0 var(--space-4);
		}

		.pt-title {
			font-size: var(--text-base);
		}

		.pt-center {
			display: none;
		}

		.pt-right :global(.pt-group) {
			display: none;
		}

		.pt-right :global(.pt-search) {
			min-width: 0;
			max-width: none;
			flex: 1;
		}
	}
</style>
