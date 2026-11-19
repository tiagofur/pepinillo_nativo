<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import logoUrl from '$lib/assets/logo.svg';
	import LangSelector from './LangSelector.svelte';

	let scrolled = $state(false);
</script>

<svelte:window onscroll={() => (scrolled = window.scrollY > 8)} />

<header class="top" class:scrolled>
	<a class="brand" href="/">
		<img src={logoUrl} alt="" width="30" height="30" />
		<span>Pepinillo</span>
	</a>
	<nav class="top-nav" aria-label={t('landing.nav.guides')}>
		<a href="/guides">{t('landing.nav.guides')}</a>
		<a href="#showcase">{t('landing.showcase.title')}</a>
		<a href="#pricing">{t('landing.nav.pricing')}</a>
		<a href="#faq">{t('landing.nav.faq')}</a>
	</nav>
	<div class="top-actions">
		<LangSelector />
		<a class="btn btn-soft pressable btn-sm" href="https://app.pepinillo.app/focus">{t('landing.nav.open')}</a>
	</div>
</header>

<style>
	.top {
		position: sticky;
		top: 0;
		z-index: 40;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		min-height: 60px;
		padding: var(--space-2) var(--space-4);
		transition:
			background-color var(--dur-base) var(--ease-out-quint),
			box-shadow var(--dur-base) var(--ease-out-quint);
	}

	.top.scrolled {
		background: var(--material-bg);
		backdrop-filter: blur(20px) saturate(1.4);
		-webkit-backdrop-filter: blur(20px) saturate(1.4);
		box-shadow: 0 1px 0 var(--hairline);
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

	.top-nav {
		display: flex;
		align-items: center;
		gap: var(--space-5);
	}

	.top-nav a {
		color: var(--ink-secondary);
		font-weight: 550;
	}

	.top-nav a:hover {
		text-decoration: none;
		color: var(--brand);
	}

	.top-actions {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.btn-sm {
		min-height: 34px;
		padding: 0 var(--space-4);
		font-size: var(--text-sm);
	}

	@media (max-width: 719px) {
		.top-nav {
			display: none;
		}
	}

	@media (max-width: 559px) {
		.top-actions .btn {
			display: none;
		}
	}
</style>
