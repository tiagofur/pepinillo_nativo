<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { initLocale, readStoredLocale, currentLocale } from '$lib/i18n/i18n.svelte';

	let lang = $state('es');
	let { children } = $props();

	onMount(() => {
		initLocale(readStoredLocale() ?? undefined);
		lang = currentLocale();
		if ('serviceWorker' in navigator) {
			navigator.serviceWorker.register('/sw.js').catch(() => undefined);
		}
	});

	// Keep <html lang> in sync with the reactive locale.
	$effect(() => {
		if (typeof document !== 'undefined') {
			document.documentElement.lang = lang;
		}
	});
</script>

{@render children?.()}
