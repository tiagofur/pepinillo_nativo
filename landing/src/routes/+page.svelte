<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL, UPGRADE_URL } from '$lib/domain/links';
	import Header from '$lib/components/landing/Header.svelte';
	import Hero from '$lib/components/landing/Hero.svelte';
	import PlatformShowcase from '$lib/components/landing/PlatformShowcase.svelte';

	const FLOW: { key: MessageKey; emoji: string }[] = [
		{ key: 'landing.flow.plan', emoji: '🗂️' },
		{ key: 'landing.flow.focus', emoji: '🎯' },
		{ key: 'landing.flow.complete', emoji: '✅' },
		{ key: 'landing.flow.reflect', emoji: '🌱' }
	];

	const FEATURES: { title: MessageKey; body: MessageKey; color: string; emoji: string }[] = [
		{ title: 'landing.feat.modes.title', body: 'landing.feat.modes.body', color: 'var(--mode-pomodoro)', emoji: '🍅' },
		{ title: 'landing.feat.tasks.title', body: 'landing.feat.tasks.body', color: 'var(--mode-flowtime)', emoji: '🗂️' },
		{ title: 'landing.feat.stats.title', body: 'landing.feat.stats.body', color: 'var(--streak)', emoji: '📈' },
		{ title: 'landing.feat.sync.title', body: 'landing.feat.sync.body', color: 'var(--mode-timeblock)', emoji: '☁️' }
	];

	const FAQ: { q: MessageKey; a: MessageKey }[] = [
		{ q: 'landing.faq.offline.q', a: 'landing.faq.offline.a' },
		{ q: 'landing.faq.devices.q', a: 'landing.faq.devices.a' },
		{ q: 'landing.faq.price.q', a: 'landing.faq.price.a' },
		{ q: 'landing.faq.account.q', a: 'landing.faq.account.a' }
	];
</script>

<svelte:head>
	<title>{t('landing.title')}</title>
	<meta name="description" content={t('landing.meta')} />
	<meta property="og:title" content={t('landing.title')} />
	<meta property="og:description" content={t('landing.meta')} />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://pepinillo.app/" />
	<meta property="og:image" content="/icons/icon-512.png" />
	<meta name="twitter:card" content="summary_large_image" />
	<link rel="canonical" href="https://pepinillo.app/" />
</svelte:head>

<Header />

<main class="landing">
	<Hero />

	<!-- Flow strip: Plan → Focus → Complete → Reflect -->
	<section class="flow" aria-label={t('landing.flow.label')}>
		{#each FLOW as step, i (step.key)}
			<div class="flow-step" style="--step-delay: {i * 90}ms">
				<span class="flow-emoji">{step.emoji}</span>
				<span class="flow-name">{t(step.key)}</span>
				{#if i < FLOW.length - 1}
					<span class="flow-arrow" aria-hidden="true">→</span>
				{/if}
			</div>
		{/each}
	</section>

	<!-- Platform showcase -->
	<PlatformShowcase />

	<!-- Features: varied rhythm, not a card grid -->
	<section class="features">
		{#each FEATURES as f, i (f.title)}
			<article class="feat" class:flip={i % 2 === 1}>
				<div class="feat-emoji" style="background: color-mix(in srgb, {f.color} 12%, transparent)">
					{f.emoji}
				</div>
				<div class="feat-copy">
					<h2>{t(f.title)}</h2>
					<p>{t(f.body)}</p>
				</div>
			</article>
		{/each}
	</section>

	<!-- Download -->
	<section class="download card">
		<h2>📱 {t('landing.download.title')}</h2>
		<p class="muted">{t('landing.download.body')}</p>
		<div class="store-row">
			<a class="btn btn-outline pressable" href={APP_STORE_URL} rel="noopener">{t('landing.download.ios')}</a>
			<a class="btn btn-outline pressable" href={PLAY_STORE_URL} rel="noopener">{t('landing.download.android')}</a>
			<a class="btn btn-ghost pressable" href={WEB_APP_URL}>{t('landing.download.web')}</a>
		</div>
		<p class="hint">{t('landing.download.pikle')}</p>
	</section>

	<!-- Pricing teaser -->
	<section class="pricing" id="pricing">
		<h2>{t('landing.pricing.title')}</h2>
		<div class="price-row">
			<div class="price-item">
				<span class="p-name">{t('upgrade.plan.free')}</span>
				<span class="p-value">$0</span>
			</div>
			<div class="price-item">
				<span class="p-name">{t('upgrade.plan.plus')}</span>
				<span class="p-value">{t('upgrade.price.plus')}</span>
			</div>
			<div class="price-item">
				<span class="p-name">{t('upgrade.plan.everywhere')}</span>
				<span class="p-value">{t('upgrade.price.everywhere')}</span>
			</div>
		</div>
		<a class="btn btn-soft pressable" href={UPGRADE_URL}>{t('landing.pricing.cta')}</a>
	</section>

	<!-- FAQ -->
	<section class="faq" id="faq">
		<h2>{t('landing.faq.title')}</h2>
		{#each FAQ as item (item.q)}
			<details class="faq-item">
				<summary>{t(item.q)}</summary>
				<p class="muted">{t(item.a)}</p>
			</details>
		{/each}
	</section>

	<!-- Guides / user manual -->
	<section class="guides card">
		<h2>📚 {t('landing.guides.title')}</h2>
		<p class="muted">{t('landing.guides.sub')}</p>
		<div class="store-row">
			<a class="btn btn-primary pressable" href="/guides/macos.html" data-sveltekit-reload>{t('landing.guides.cta')}</a>
			<a class="btn btn-ghost pressable" href="/guides">{t('landing.nav.guides')}</a>
		</div>
	</section>

	<footer class="foot">
		<a href="/guides">{t('landing.nav.guides')}</a>
		<span class="dot">·</span>
		<a href="/guides/macos.html" data-sveltekit-reload>{t('landing.nav.macmanual')}</a>
		<span class="dot">·</span>
		<a href={UPGRADE_URL}>{t('landing.nav.pricing')}</a>
		<span class="dot">·</span>
		<a href="https://creapolis.dev/privacy-policy">{t('legal.privacy')}</a>
		<span class="dot">·</span>
		<a href="https://creapolis.dev/terms-of-use">{t('legal.terms')}</a>
		<span class="dot">·</span>
		<span>© 2026 Creapolis</span>
	</footer>
</main>

<style>
	.landing {
		max-width: 1040px;
		margin-inline: auto;
		padding: 0 var(--space-5) calc(var(--space-12) + var(--safe-b));
		display: flex;
		flex-direction: column;
		gap: var(--space-16);
		overflow-x: clip; /* the decorative glows bleed intentionally */
	}

	/* Flow strip */
	.flow {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		flex-wrap: wrap;
		justify-content: center;
		padding: var(--space-5) var(--space-6);
		border-block: 1px solid var(--hairline);
	}

	.flow-step {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		animation: rise-in var(--dur-slow) var(--ease-out-quint) both;
		animation-delay: var(--step-delay);
	}

	.flow-emoji {
		font-size: 22px;
	}

	.flow-name {
		font-weight: 650;
		color: var(--ink-secondary);
	}

	.flow-arrow {
		color: var(--faint);
		margin-inline-start: var(--space-2);
	}

	/* Features: alternating rhythm */
	.features {
		display: flex;
		flex-direction: column;
		gap: var(--space-10);
	}

	.feat {
		display: flex;
		align-items: center;
		gap: var(--space-6);
		max-width: 720px;
	}

	.feat.flip {
		margin-inline-start: auto;
		flex-direction: row-reverse;
		text-align: end;
	}

	.feat-emoji {
		flex: none;
		width: 72px;
		height: 72px;
		border-radius: var(--radius-lg);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 32px;
	}

	.feat h2 {
		font-size: var(--text-lg);
		margin-bottom: var(--space-2);
	}

	.feat p {
		color: var(--muted);
		max-width: 46ch;
	}

	.feat.flip p {
		margin-inline-start: auto;
	}

	.download {
		padding: var(--space-6);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.download h2 {
		font-size: var(--text-lg);
	}

	.muted {
		color: var(--muted);
	}

	.hint {
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.store-row {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	.pricing {
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-5);
	}

	.price-row {
		display: flex;
		gap: var(--space-6);
		flex-wrap: wrap;
		justify-content: center;
	}

	.price-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.p-name {
		font-size: var(--text-sm);
		color: var(--muted);
		font-weight: 650;
	}

	.p-value {
		font-weight: 750;
		font-size: var(--text-md);
	}

	.faq {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-width: 720px;
	}

	.guides {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-width: 720px;
		text-align: center;
		align-items: center;
	}

	.faq-item {
		border-bottom: 1px solid var(--hairline);
		padding-bottom: var(--space-3);
	}

	summary {
		font-weight: 650;
		cursor: pointer;
		min-height: var(--touch-target);
		display: flex;
		align-items: center;
	}

	.foot {
		display: flex;
		justify-content: center;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.foot a {
		color: var(--faint);
	}

	.dot {
		color: var(--border-strong);
	}

	@media (max-width: 599px) {
		.feat,
		.feat.flip {
			flex-direction: column;
			text-align: start;
			gap: var(--space-3);
		}

		.feat.flip p {
			margin-inline-start: 0;
		}
	}

	@keyframes rise-in {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}
</style>
