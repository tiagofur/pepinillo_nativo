<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import favicon from '$lib/assets/favicon.svg';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/messages';

	let { children } = $props();

	onMount(() => {
		void app.init();
	});

	const locale = $derived(app.locale);

	async function dismissOnboarding(skip: boolean) {
		void skip;
		await app.completeOnboarding();
	}

	function pathCurrent(href: string): boolean {
		const path = $page.url.pathname.replace(/\/$/, '') || '/';
		const target = href.replace(/\/$/, '') || '/';
		return path === target || path.startsWith(target + '/');
	}
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link
		href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600&family=Source+Sans+3:wght@400;600;650&display=swap"
		rel="stylesheet"
	/>
	<meta name="robots" content="noindex, nofollow" />
	<title>Pepinillo · Web companion</title>
</svelte:head>

<div class="app-shell">
	<header class="app-header">
		<div class="brand">
			<span class="brand-name">{t(locale, 'app.name')}</span>
			<span class="brand-tag">{t(locale, 'app.tagline')}</span>
		</div>
		<nav class="nav" aria-label="Primary">
			<a href="/focus/" aria-current={pathCurrent('/focus') ? 'page' : undefined}
				>{t(locale, 'nav.focus')}</a
			>
			<a href="/plan/" aria-current={pathCurrent('/plan') ? 'page' : undefined}
				>{t(locale, 'nav.plan')}</a
			>
			<a href="/dashboard/" aria-current={pathCurrent('/dashboard') ? 'page' : undefined}
				>{t(locale, 'nav.dashboard')}</a
			>
			<a href="/account/" aria-current={pathCurrent('/account') ? 'page' : undefined}
				>{t(locale, 'nav.account')}</a
			>
		</nav>
	</header>

	<main class="app-main">
		{#if app.ready}
			{@render children()}
		{:else}
			<p class="muted">Loading…</p>
		{/if}
	</main>

	<footer class="app-footer">{t(locale, 'footer.companion')}</footer>
</div>

{#if app.onboardingOpen}
	<div class="overlay" role="dialog" aria-modal="true" aria-labelledby="onboard-title">
		<div class="dialog">
			<h2 id="onboard-title">{t(locale, 'onboarding.title')}</h2>
			<p>{t(locale, 'onboarding.body')}</p>
			<p>{t(locale, 'onboarding.limits')}</p>
			<p class="banner banner-warn">{t(locale, 'onboarding.browserOnly')}</p>
			<p class="banner">{t(locale, 'onboarding.timerHonesty')}</p>
			<div class="row">
				<button class="btn btn-primary" type="button" onclick={() => dismissOnboarding(false)}>
					{t(locale, 'onboarding.continue')}
				</button>
				<button class="btn btn-ghost" type="button" onclick={() => dismissOnboarding(true)}>
					{t(locale, 'onboarding.skip')}
				</button>
			</div>
		</div>
	</div>
{/if}
