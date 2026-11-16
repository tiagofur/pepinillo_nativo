<script lang="ts">
	/**
	 * Apple-style segmented control with a sliding thumb.
	 * options: { id, label, disabled?, title? }[] — single selection.
	 */
	let {
		options,
		value,
		onchange,
		compact = false
	}: {
		options: { id: string; label: string; disabled?: boolean; title?: string }[];
		value: string;
		onchange: (id: string) => void;
		compact?: boolean;
	} = $props();

	let activeIndex = $derived(Math.max(0, options.findIndex((o) => o.id === value)));
</script>

<div class="segmented" class:compact role="tablist" style="--count: {options.length}">
	<span
		class="thumb"
		style="width: {100 / options.length}%; transform: translateX({activeIndex * 100}%)"
		aria-hidden="true"
	></span>
	{#each options as o (o.id)}
		<button
			type="button"
			role="tab"
			aria-selected={o.id === value}
			class:is-active={o.id === value}
			class:is-locked={o.disabled}
			disabled={o.disabled}
			title={o.title}
			onclick={() => !o.disabled && onchange(o.id)}
		>
			{o.label}
		</button>
	{/each}
</div>

<style>
	.segmented {
		position: relative;
		display: inline-grid;
		grid-auto-flow: column;
		grid-auto-columns: 1fr;
		padding: 2px;
		border-radius: 9px;
		background: var(--surface-sunken);
		border: 1px solid var(--hairline);
	}

	.thumb {
		position: absolute;
		top: 2px;
		bottom: 2px;
		left: 2px;
		width: calc((100% - 4px) / var(--count));
		border-radius: 7px;
		background: var(--surface);
		box-shadow:
			0 1px 3px rgba(0, 0, 0, 0.12),
			0 0 1px rgba(0, 0, 0, 0.08);
		transition: transform var(--dur-base) var(--ease-out-quint);
	}

	button {
		position: relative;
		z-index: 1;
		min-height: 32px;
		padding: 0 var(--space-4);
		border: none;
		background: none;
		border-radius: 7px;
		font-weight: 550;
		font-size: var(--text-sm);
		color: var(--muted);
		cursor: pointer;
		white-space: nowrap;
		transition: color var(--dur-fast) var(--ease-out-quint);
	}

	button.is-active {
		color: var(--ink);
		font-weight: 650;
	}

	button.is-locked {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.compact button {
		min-height: 28px;
		padding: 0 var(--space-3);
		font-size: var(--text-xs);
	}

	@media (prefers-reduced-motion: reduce) {
		.thumb {
			transition: none;
		}
	}
</style>
