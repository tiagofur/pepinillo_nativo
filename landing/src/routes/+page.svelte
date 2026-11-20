<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import Header from '$lib/components/landing/Header.svelte';
	import Hero from '$lib/components/landing/Hero.svelte';
	import FlowStrip from '$lib/components/landing/FlowStrip.svelte';
	import PlatformShowcase from '$lib/components/landing/PlatformShowcase.svelte';
	import Features from '$lib/components/landing/Features.svelte';
	import Pricing from '$lib/components/landing/Pricing.svelte';
	import Faq from '$lib/components/landing/Faq.svelte';
	import FinalCta from '$lib/components/landing/FinalCta.svelte';
	import Footer from '$lib/components/landing/Footer.svelte';
</script>

<svelte:head>
	<title>{t('landing.title')}</title>
	<meta name="description" content={t('landing.meta')} />
	<meta property="og:title" content={t('landing.title')} />
	<meta property="og:description" content={t('landing.meta')} />
	<meta property="og:type" content="website" />
	<meta property="og:url" content="https://pepinillo.app/" />
	<meta property="og:image" content="https://pepinillo.app/img/og-card.png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content={t('app.tagline')} />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:image" content="https://pepinillo.app/img/og-card.png" />
	<link rel="canonical" href="https://pepinillo.app/" />
</svelte:head>

<Header />

<main class="landing">
	<Hero />
	<FlowStrip />
	<PlatformShowcase />
	<Features />
	<Pricing />
	<Faq />
	<FinalCta />
</main>

<Footer />

<style>
	.landing {
		max-width: 1040px;
		margin-inline: auto;
		padding: 0 var(--space-5) var(--space-16);
		display: flex;
		flex-direction: column;
		gap: var(--space-16);
		overflow-x: clip;
	}
</style>
