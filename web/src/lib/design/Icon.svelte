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
	{:else if name === 'tray'}
		<path d="M3.5 13h4.5l2 3h4l2-3h4.5" />
		<path d="M3.5 13v4a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-4" />
		<path d="M6.2 13 8 5.5h8l1.8 7.5" />
	{:else if name === 'sun'}
		<circle cx="12" cy="12" r="4" />
		<path d="M12 2.5V5" />
		<path d="M12 19v2.5" />
		<path d="M2.5 12H5" />
		<path d="M19 12h2.5" />
		<path d="M4.9 4.9l1.8 1.8" />
		<path d="M17.3 17.3l1.8 1.8" />
		<path d="M19.1 4.9l-1.8 1.8" />
		<path d="M6.7 17.3l-1.8 1.8" />
	{:else if name === 'calendar'}
		<rect x="3.5" y="5" width="17" height="15.5" rx="2.5" />
		<path d="M3.5 9.5h17" />
		<path d="M8 2.5V6" />
		<path d="M16 2.5V6" />
	{:else if name === 'check-circle'}
		<circle cx="12" cy="12" r="8.5" />
		<path d="M8 12.4l2.7 2.7L16 9.5" />
	{:else if name === 'gear'}
		<circle cx="12" cy="12" r="3" />
		<path
			d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"
		/>
	{:else if name === 'plus'}
		<path d="M12 5v14" />
		<path d="M5 12h14" />
	{:else if name === 'search'}
		<circle cx="11" cy="11" r="7" />
		<path d="M16.5 16.5 21 21" />
	{:else if name === 'inspector'}
		<rect x="3.5" y="4.5" width="17" height="15" rx="2.5" />
		<path d="M14.5 4.5v15" />
	{:else if name === 'refresh'}
		<path d="M20.5 12a8.5 8.5 0 1 1-2.5-6" />
		<path d="M18.5 2.5v4h-4" />
	{:else if name === 'chevron'}
		<path d="M6 9l6 6 6-6" />
	{:else if name === 'waveform'}
		<path d="M3 12h2" />
		<path d="M8 8v8" />
		<path d="M12 5v14" />
		<path d="M16 8v8" />
		<path d="M19 12h2" />
	{:else if name === 'cup'}
		<path d="M5 8h12v5a5 5 0 01-5 5h-2a5 5 0 01-5-5V8z" />
		<path d="M17 9h1.5a2.5 2.5 0 010 5H17" />
		<path d="M7 21h8" />
	{:else if name === 'clock'}
		<circle cx="12" cy="12" r="8.5" />
		<path d="M12 7.5V12l3 2" />
	{:else if name === 'flame'}
		<path d="M12 3c1 3-2 4.5-2 7a4 4 0 008 0c0-1.5-.6-2.6-1.4-3.6C15.4 8 14 8.6 14 10" />
		<path d="M8 13.5A6.5 6.5 0 0012 21a6.5 6.5 0 004-7.5" />
	{:else if name === 'checklist'}
		<path d="M4 6.5l1.4 1.4L8 5.3" />
		<path d="M4 12.5l1.4 1.4L8 11.3" />
		<path d="M4 18.5l1.4 1.4L8 17.3" />
		<path d="M11 6.5h9" />
		<path d="M11 12.5h9" />
		<path d="M11 18.5h9" />
	{/if}
</svg>
