<script lang="ts">
	import { onMount } from 'svelte';
	// The guides live on the marketing site (landing/). In production the
	// app-domain nginx already 302s /guides there; this page covers the dev
	// server and any direct navigation that bypasses nginx.
	onMount(() => {
		window.location.href = 'https://pepinillo.app/guides';
	});
</script>

<p class="redirecting">Opening the guides…</p>

<style>
	.redirecting {
		color: var(--muted);
		font-size: var(--text-sm);
		text-align: center;
		padding: var(--space-12) 0;
	}
</style>
