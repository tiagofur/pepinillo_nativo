<script lang="ts" module>
	import type { FocusMode } from '$lib/domain/entities/types';
	export type { FocusMode };
</script>

<script lang="ts">
	let {
		mode,
		size = 18
	}: {
		mode: FocusMode;
		size?: number;
	} = $props();
</script>

<svg
	class="mode-svg"
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.85"
	stroke-linecap="round"
	stroke-linejoin="round"
	aria-hidden="true"
>
	{#if mode === 'pomodoro'}
		<!-- Tomato-ish timer -->
		<circle cx="12" cy="13" r="7.5" />
		<path d="M12 9.5v4" />
		<path d="M9.5 4.5c1 .9 2 .9 2.5.9s1.5 0 2.5-.9" />
		<path d="M12 5.4V3.8" />
	{:else if mode === 'stopwatch'}
		<circle cx="12" cy="13" r="7.5" />
		<path d="M12 13V9.5" />
		<path d="M12 13l3 2" />
		<path d="M9 3.5h6" />
		<path d="M12 3.5V5.2" />
	{:else if mode === 'flowtime'}
		<!-- Flow waves -->
		<path d="M3 9c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2" />
		<path d="M3 14c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2" />
		<path d="M3 19c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2" />
	{:else}
		<!-- Time block calendar -->
		<rect x="4" y="5" width="16" height="15" rx="2" />
		<path d="M8 3.5v3" />
		<path d="M16 3.5v3" />
		<path d="M4 10h16" />
		<path d="M8 14h3" />
		<path d="M13 14h3" />
		<path d="M8 17h5" />
	{/if}
</svg>

<style>
	.mode-svg {
		display: block;
		flex-shrink: 0;
	}
</style>
