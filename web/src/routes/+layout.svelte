<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { initLocale, readStoredLocale, currentLocale } from '$lib/i18n/i18n.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { toast } from '$lib/stores/toast.svelte';
	import { startDeployWatch } from '$lib/system/deploy-version';

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
		// Stale-tab cure (#974): a tab running an old deploy learns that a new
		// one landed and offers a reload — never auto-reload mid-focus-session.
		startDeployWatch(() => {
			toast.action(t('update.available'), t('update.reload'), () => location.reload(), 60_000);
		});
	});

	// Keep <html lang> in sync with the reactive locale.
	$effect(() => {
		if (typeof document !== 'undefined') {
			document.documentElement.lang = lang;
		}
	});
</script>

{@render children?.()}
