<script lang="ts" module>
	export type NavIconName = 'focus' | 'plan' | 'dashboard' | 'account';
</script>

<script lang="ts">
	let {
		name,
		size = 22
	}: {
		name: NavIconName;
		size?: number;
	} = $props();
</script>

<svg
	class="nav-svg"
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill="none"
	stroke="currentColor"
	stroke-width="1.75"
	stroke-linecap="round"
	stroke-linejoin="round"
	aria-hidden="true"
>
	{#if name === 'focus'}
		<!-- Timer / target -->
		<circle cx="12" cy="13" r="8" />
		<path d="M12 9v4l2.5 1.5" />
		<path d="M12 5V3" />
		<path d="M9 3h6" />
	{:else if name === 'plan'}
		<!-- Checklist -->
		<path d="M9 5h11" />
		<path d="M9 12h11" />
		<path d="M9 19h11" />
		<path d="M4 5.5l1.2 1.2L7.2 4.5" />
		<path d="M4 12.5l1.2 1.2L7.2 11.5" />
		<path d="M4 19.5l1.2 1.2L7.2 18.5" />
	{:else if name === 'dashboard'}
		<!-- Bar chart -->
		<path d="M4 19h16" />
		<path d="M7 16V10" />
		<path d="M12 16V6" />
		<path d="M17 16v-4" />
	{:else}
		<!-- Account person -->
		<circle cx="12" cy="8" r="3.25" />
		<path d="M5.5 19.5c1.4-3.2 3.7-4.75 6.5-4.75s5.1 1.55 6.5 4.75" />
	{/if}
</svg>

<style>
	.nav-svg {
		display: block;
	}
</style>
