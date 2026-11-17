<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { initLocale, readStoredLocale, currentLocale } from '$lib/i18n/i18n.svelte';

	let lang = $state('es');
	let { children } = $props();

	onMount(() => {
		initLocale(readStoredLocale() ?? undefined);
		lang = currentLocale();
		// PWA only in production builds: in dev the cache-first SW serves stale
		// modules and masks every edit.
		if ('serviceWorker' in navigator && import.meta.env.PROD) {
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
