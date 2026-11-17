<script lang="ts">
	/**
	 * Inline stroke icons for navigation and controls.
	 * SF-Symbols-like weight: 1.8 stroke, round caps — reads native on
	 * Apple and Android alike. 24×24 grid.
	 */
	let { name, size = 24 }: { name: string; size?: number } = $props();
</script>

<svg
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.8"
	stroke-linecap="round"
	stroke-linejoin="round"
	aria-hidden="true"
>
	{#if name === 'focus'}
		<circle cx="12" cy="13" r="7.5" />
		<circle cx="12" cy="13" r="3" />
		<path d="M12 2.5v3" />
		<path d="M5.4 6.4l1.8 1.8" />
		<path d="M18.6 6.4l-1.8 1.8" />
	{:else if name === 'plan'}
		<path d="M4 6.5l1.4 1.4L8 5.3" />
		<path d="M4 12.5l1.4 1.4L8 11.3" />
		<path d="M4 18.5l1.4 1.4L8 17.3" />
		<path d="M11 6.5h9" />
		<path d="M11 12.5h9" />
		<path d="M11 18.5h9" />
	{:else if name === 'dashboard'}
		<path d="M4 20V10" />
		<path d="M10 20V4" />
		<path d="M16 20v-7" />
		<path d="M22 20H2" />
	{:else if name === 'account'}
		<circle cx="12" cy="8" r="3.6" />
		<path d="M5 20c.8-3.6 3.6-5.4 7-5.4s6.2 1.8 7 5.4" />
	{:else if name === 'lock'}
		<rect x="5.5" y="10.5" width="13" height="9" rx="2.5" />
		<path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5" />
	{:else if name === 'play'}
		<path d="M8 5.5v13l10-6.5z" fill="currentColor" stroke="none" />
	{:else if name === 'pause'}
		<rect x="7" y="5.5" width="3.4" height="13" rx="1.4" fill="currentColor" stroke="none" />
		<rect x="13.6" y="5.5" width="3.4" height="13" rx="1.4" fill="currentColor" stroke="none" />
	{:else if name === 'stop'}
		<rect x="6.5" y="6.5" width="11" height="11" rx="2.4" fill="currentColor" stroke="none" />
	{:else if name === 'skip'}
		<path d="M6 5.5v13l9-6.5z" fill="currentColor" stroke="none" />
		<rect x="16" y="5.5" width="2.6" height="13" rx="1.2" fill="currentColor" stroke="none" />
	{/if}
</svg>
