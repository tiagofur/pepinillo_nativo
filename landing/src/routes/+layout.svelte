<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { initLocale, readStoredLocale, currentLocale } from '$lib/i18n/i18n.svelte';

	let lang = $state('es');
	let { children } = $props();

	onMount(() => {
		initLocale(readStoredLocale() ?? undefined);
		lang = currentLocale();
	});

	$effect(() => {
		if (typeof document !== 'undefined') {
			document.documentElement.lang = lang;
		}
	});
</script>

{@render children?.()}
