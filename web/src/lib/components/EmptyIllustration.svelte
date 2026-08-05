<script lang="ts">
	let {
		kind = 'tasks'
	}: {
		kind?: 'tasks' | 'dashboard' | 'generic';
	} = $props();
</script>

<svg
	class="empty-illu"
	viewBox="0 0 120 88"
	fill="none"
	xmlns="http://www.w3.org/2000/svg"
	aria-hidden="true"
>
	{#if kind === 'tasks'}
		<rect x="22" y="18" width="76" height="54" rx="10" class="illu-surface" />
		<rect x="34" y="30" width="12" height="12" rx="3" class="illu-accent" opacity="0.35" />
		<rect x="52" y="32" width="34" height="8" rx="3" class="illu-muted" />
		<rect x="34" y="48" width="12" height="12" rx="3" class="illu-accent" />
		<rect x="52" y="50" width="28" height="8" rx="3" class="illu-muted" />
		<path d="M37 53.5l2.5 2.5 5-5" class="illu-stroke" stroke-width="1.6" />
	{:else if kind === 'dashboard'}
		<rect x="18" y="20" width="84" height="50" rx="12" class="illu-surface" />
		<path
			d="M34 54V42M52 54V30M70 54V38M88 54V34"
			class="illu-accent"
			stroke-width="6"
			stroke-linecap="round"
		/>
		<circle cx="96" cy="26" r="10" class="illu-soft" />
	{:else}
		<circle cx="60" cy="44" r="28" class="illu-surface" />
		<circle cx="60" cy="44" r="18" class="illu-soft" />
		<path d="M60 32v14l8 5" class="illu-accent" stroke-width="2.5" stroke-linecap="round" />
	{/if}
</svg>

<style>
	.empty-illu {
		width: min(9.5rem, 48vw);
		height: auto;
		display: block;
		margin: 0 auto var(--space-3);
	}

	.empty-illu :global(.illu-surface) {
		fill: var(--surface);
		stroke: var(--border);
		stroke-width: 1;
	}

	.empty-illu :global(.illu-muted) {
		fill: color-mix(in srgb, var(--muted) 35%, var(--surface));
	}

	.empty-illu :global(.illu-accent) {
		fill: none;
		stroke: var(--accent);
	}

	.empty-illu :global(rect.illu-accent) {
		fill: var(--accent);
		stroke: none;
	}

	.empty-illu :global(.illu-soft) {
		fill: var(--accent-soft);
		stroke: none;
	}

	.empty-illu :global(.illu-stroke) {
		fill: none;
		stroke: var(--accent-fg, #fff);
	}
</style>
