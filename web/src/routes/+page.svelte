<script lang="ts">
	import { onMount } from 'svelte';

	// App-only build: the marketing site lives in `web-landing/` (pepinillo.app).
	// The app root opens Focus directly (installed PWA and deep links).
	onMount(() => {
		window.location.replace('/focus');
	});
</script>

<svelte:head>
	<meta http-equiv="refresh" content="0;url=/focus" />
	<title>Pepinillo</title>
</svelte:head>
