<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import favicon from '$lib/assets/favicon.svg';
	import { app } from '$lib/stores/app.svelte';
	import { t, type MessageKey } from '$lib/i18n/messages';
	import NavIcons from '$lib/components/icons/NavIcons.svelte';

	let { children } = $props();

	onMount(() => {
		void app.init();
	});

	const locale = $derived(app.locale);

	const toastText = $derived.by(() => {
		const raw = app.toast;
		if (!raw) return null;
		if (raw.startsWith('toast.')) {
			return t(locale, raw as MessageKey);
		}
		return raw;
	});

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
	<meta name="robots" content="noindex, nofollow" />
	<meta name="theme-color" content="#38803b" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
	<title>Pepinillo</title>
</svelte:head>

<div class="app-shell">
	<header class="app-topbar">
		<div class="brand">
			<span class="brand-mark" aria-hidden="true"></span>
			<div class="brand-text">
				<span class="brand-name">{t(locale, 'app.name')}</span>
				<span class="brand-tag">{t(locale, 'app.tagline')}</span>
			</div>
		</div>
		<span class="topbar-meta">Free</span>
	</header>

	<main class="app-main">
		{#if app.ready}
			{@render children()}
		{:else}
			<p class="muted">Loading…</p>
		{/if}
	</main>

	<nav class="tab-bar" aria-label="Primary">
		<a href="/focus/" aria-current={pathCurrent('/focus') ? 'page' : undefined}>
			<span class="tab-icon" aria-hidden="true"><NavIcons name="focus" /></span>
			<span class="tab-label">{t(locale, 'nav.focus')}</span>
		</a>
		<a href="/plan/" aria-current={pathCurrent('/plan') ? 'page' : undefined}>
			<span class="tab-icon" aria-hidden="true"><NavIcons name="plan" /></span>
			<span class="tab-label">{t(locale, 'nav.plan')}</span>
		</a>
		<a href="/dashboard/" aria-current={pathCurrent('/dashboard') ? 'page' : undefined}>
			<span class="tab-icon" aria-hidden="true"><NavIcons name="dashboard" /></span>
			<span class="tab-label">{t(locale, 'nav.dashboard')}</span>
		</a>
		<a href="/account/" aria-current={pathCurrent('/account') ? 'page' : undefined}>
			<span class="tab-icon" aria-hidden="true"><NavIcons name="account" /></span>
			<span class="tab-label">{t(locale, 'nav.account')}</span>
		</a>
	</nav>

	<p class="app-footer-note">{t(locale, 'footer.companion')}</p>
</div>

{#if toastText}
	<div class="toast" role="status" aria-live="polite">
		<span>{toastText}</span>
		<button type="button" class="toast-dismiss" onclick={() => app.dismissToast()} aria-label="Dismiss">
			×
		</button>
	</div>
{/if}

{#if app.onboardingOpen}
	<div class="overlay" role="dialog" aria-modal="true" aria-labelledby="onboard-title">
		<div class="dialog">
			<h2 id="onboard-title">{t(locale, 'onboarding.title')}</h2>
			<p>{t(locale, 'onboarding.body')}</p>
			<p>{t(locale, 'onboarding.limits')}</p>
			<p class="banner banner-warn">{t(locale, 'onboarding.browserOnly')}</p>
			<p class="banner banner-soft">{t(locale, 'onboarding.timerHonesty')}</p>
			<div class="stack">
				<button class="btn btn-primary btn-block" type="button" onclick={() => dismissOnboarding(false)}>
					{t(locale, 'onboarding.continue')}
				</button>
				<button class="btn btn-ghost btn-block" type="button" onclick={() => dismissOnboarding(true)}>
					{t(locale, 'onboarding.skip')}
				</button>
			</div>
		</div>
	</div>
{/if}
