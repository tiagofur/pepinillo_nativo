export const prerender = true;
<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { auth } from '$lib/stores/auth.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Icon from '$lib/design/Icon.svelte';
	import logoUrl from '$lib/assets/logo.svg';

	// Pricing mirrors prd-v2 §monetización (LATAM-first copy).
	const PLANS: {
		id: 'free' | 'pepinillo_plus' | 'everywhere';
		key: MessageKey;
		price: MessageKey;
		note: MessageKey;
		features: MessageKey[];
	}[] = [
		{
			id: 'free',
			key: 'upgrade.plan.free',
			price: 'upgrade.price.free',
			note: 'upgrade.note.free',
			features: [
				'upgrade.free.pomodoro',
				'upgrade.free.stopwatch',
				'upgrade.free.tasks',
				'upgrade.free.analytics'
			]
		},
		{
			id: 'pepinillo_plus',
			key: 'upgrade.plan.plus',
			price: 'upgrade.price.plus',
			note: 'upgrade.note.plus',
			features: [
				'upgrade.plus.modes',
				'upgrade.plus.tasks',
				'upgrade.plus.subtasks',
				'upgrade.plus.themes',
				'upgrade.plus.analytics',
				'upgrade.plus.soundscapes'
			]
		},
		{
			id: 'everywhere',
			key: 'upgrade.plan.everywhere',
			price: 'upgrade.price.everywhere',
			note: 'upgrade.note.everywhere',
			features: [
				'upgrade.everywhere.plusIncluded',
				'upgrade.everywhere.sync',
				'upgrade.everywhere.ai',
				'upgrade.everywhere.recovery',
				'upgrade.everywhere.web'
			]
		}
	];

	let busyPlan = $state<string | null>(null);
	let errorText = $state('');
	let portalBusy = $state(false);

	onMount(() => {
		// Returning from Stripe Checkout: refresh the tier without re-login
		// (S4 #942) and clean the query param.
		if (page.url.searchParams.get('checkout') === 'success') {
			void auth.refreshEntitlement();
			history.replaceState({}, '', page.url.pathname);
		}
		void auth.init();
	});

	/**
	 * Apple policy mitigation: on Apple devices the App Store is the primary
	 * purchase path; Stripe stays available as a secondary option.
	 */
	let isAppleTraffic = $derived(
		typeof navigator !== 'undefined' &&
			/iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent) &&
			!/Chrome|Firefox|Edg/.test(navigator.userAgent)
	);

	const APP_STORE_URL = 'https://apps.apple.com/search?term=pepinillo%20creapolis';
	const PLAY_STORE_URL = 'https://play.google.com/store/search?q=pepinillo%20creapolis&c=apps';

	async function buy(plan: 'pepinillo_plus' | 'everywhere_monthly' | 'everywhere_annual'): Promise<void> {
		errorText = '';
		if (!auth.configured) {
			errorText = t('auth.apiMissing');
			return;
		}
		if (!auth.user) {
			await gotoSignIn();
			return;
		}
		busyPlan = plan;
		try {
			const res = await auth.api!.createStripeCheckout(plan);
			window.location.href = res.checkoutUrl;
		} catch {
			errorText = t('upgrade.checkoutError');
		} finally {
			busyPlan = null;
		}
	}

	async function openPortal(): Promise<void> {
		if (!auth.api) return;
		portalBusy = true;
		errorText = '';
		try {
			const res = await auth.api.createStripePortal();
			window.location.href = res.portalUrl;
		} catch {
			errorText = t('upgrade.portalError');
		} finally {
			portalBusy = false;
		}
	}

	async function gotoSignIn(): Promise<void> {
		const { goto } = await import('$app/navigation');
		await goto('/account');
	}

	function storeUrl(): string {
		if (typeof navigator === 'undefined') return APP_STORE_URL;
		return /Android/.test(navigator.userAgent) ? PLAY_STORE_URL : APP_STORE_URL;
	}
</script>

<svelte:head>
	<title>{t('upgrade.title')} · Pepinillo</title>
	<meta name="description" content={t('upgrade.meta')} />
	<meta property="og:url" content="https://app.pepinillo.app/upgrade" />
	<link rel="canonical" href="https://app.pepinillo.app/upgrade" />
</svelte:head>

<main class="upgrade">
	<header class="top">
		<a class="brand" href="/">
			<img src={logoUrl} alt="" width="30" height="30" />
			<span>Pepinillo</span>
		</a>
	</header>

	<section class="hero rise-in">
		<h1>{t('upgrade.headline')}</h1>
		<p class="sub">{t('upgrade.sub')}</p>
	</section>

	{#if auth.user}
		<p class="signed-in muted">✓ {t('upgrade.signedIn', { email: auth.user.email })}</p>
	{:else}
		<p class="muted sign-hint">{t('upgrade.signInFirst')} — <button class="link" onclick={gotoSignIn}>{t('auth.signIn')}</button></p>
	{/if}

	<section class="plans">
		{#each PLANS as plan (plan.id)}
			<article class="card plan" class:featured={plan.id === 'everywhere'}>
				{#if plan.id === 'everywhere'}
					<span class="flag">{t('upgrade.flag.best')}</span>
				{/if}
				<h2>{t(plan.key)}</h2>
				<p class="price">{t(plan.price)}</p>
				<p class="note muted">{t(plan.note)}</p>
				<ul class="features">
					{#each plan.features as f (f)}
						<li>✓ {t(f)}</li>
					{/each}
				</ul>
				<div class="cta">
					{#if plan.id === 'free'}
						<a class="btn btn-outline pressable" href="/focus">{t('upgrade.cta.free')}</a>
					{:else if plan.id === 'pepinillo_plus'}
						<button
							class="btn btn-soft pressable"
							disabled={busyPlan !== null}
							onclick={() => buy('pepinillo_plus')}
						>
							{busyPlan === 'pepinillo_plus' ? t('upgrade.working') : t('upgrade.cta.plus')}
						</button>
					{:else}
						<button
							class="btn btn-primary pressable"
							disabled={busyPlan !== null}
							onclick={() => buy('everywhere_monthly')}
						>
							{busyPlan === 'everywhere_monthly' ? t('upgrade.working') : t('upgrade.cta.everywhere')}
						</button>
					{/if}
				</div>
			</article>
		{/each}
	</section>

	{#if errorText}
		<p class="error">{errorText}</p>
	{/if}

	<section class="stores card">
		<h2>📱 {t('upgrade.storesTitle')}</h2>
		<p class="muted">{t('upgrade.storesBody')}</p>
		<div class="store-row">
			<a class="btn btn-outline pressable" href={storeUrl()} rel="noopener">{t('upgrade.storeApp')}</a>
			<a class="btn btn-ghost pressable" href={PLAY_STORE_URL} rel="noopener">{t('upgrade.storePlay')}</a>
		</div>
	</section>

	{#if auth.user}
		<section class="manage card">
			<h2>🛠️ {t('upgrade.manageTitle')}</h2>
			<p class="muted">{t('upgrade.manageBody')}</p>
			<div class="store-row">
				<button class="btn btn-outline pressable" disabled={portalBusy} onclick={openPortal}>
					{portalBusy ? t('upgrade.working') : t('upgrade.manageCta')}
				</button>
			</div>
		</section>
	{/if}

	<footer class="foot">
		<a href="https://creapolis.dev/privacy-policy">{t('legal.privacy')}</a>
		<span class="dot">·</span>
		<a href="https://creapolis.dev/terms-of-use">{t('legal.terms')}</a>
		<span class="dot">·</span>
		<span>Creapolis</span>
	</footer>
</main>

<style>
	.upgrade {
		min-height: 100dvh;
		max-width: 960px;
		margin-inline: auto;
		padding: var(--space-6) var(--space-5) calc(var(--space-12) + var(--safe-b));
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
	}

	.top {
		display: flex;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-weight: 800;
		letter-spacing: var(--tracking-tight);
		color: var(--ink);
		font-size: var(--text-md);
	}

	.hero {
		text-align: center;
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding-top: var(--space-6);
	}

	h1 {
		font-size: var(--text-xl);
	}

	.sub {
		color: var(--muted);
		max-width: 56ch;
		margin-inline: auto;
	}

	.muted {
		color: var(--muted);
	}

	.sign-hint {
		text-align: center;
	}

	.link {
		background: none;
		border: none;
		color: var(--brand);
		font-weight: 650;
		cursor: pointer;
		padding: 0;
	}

	.plans {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
		gap: var(--space-4);
		align-items: stretch;
	}

	.plan {
		padding: var(--space-6);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		position: relative;
	}

	.plan.featured {
		border-color: var(--brand);
		box-shadow: var(--ring-glow);
	}

	.flag {
		position: absolute;
		top: calc(-1 * var(--space-3));
		right: var(--space-4);
		background: var(--brand);
		color: var(--on-brand);
		font-size: var(--text-2xs);
		font-weight: 700;
		padding: 4px 10px;
		border-radius: var(--radius-pill);
	}

	h2 {
		font-size: var(--text-md);
	}

	.price {
		font-size: var(--text-lg);
		font-weight: 750;
	}

	.note {
		font-size: var(--text-xs);
	}

	.features {
		list-style: none;
		margin: 0 0 var(--space-2);
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-size: var(--text-sm);
		color: var(--ink-secondary);
	}

	.cta {
		margin-top: auto;
	}

	.cta .btn {
		width: 100%;
	}

	.error {
		text-align: center;
		color: var(--mode-pomodoro);
		font-weight: 600;
	}

	.stores,
	.manage {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.stores h2,
	.manage h2 {
		font-size: var(--text-base);
	}

	.store-row {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	.foot {
		display: flex;
		justify-content: center;
		gap: var(--space-2);
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.foot a {
		color: var(--faint);
	}

	.dot {
		color: var(--border-strong);
	}

	@media (prefers-reduced-motion: reduce) {
		.rise-in {
			animation: none;
		}
	}
</style>
