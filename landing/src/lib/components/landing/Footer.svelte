<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import { APP_STORE_URL, PLAY_STORE_URL, UPGRADE_URL } from './links';
	import logoUrl from '$lib/assets/logo.svg';
</script>

<footer class="foot">
	<a class="brand" href="/">
		<img src={logoUrl} alt="" width="26" height="26" />
		<span>Pepinillo</span>
	</a>
	<nav class="foot-links" aria-label={t('landing.nav.guides')}>
		<a href="/guides">{t('landing.nav.guides')}</a>
		<a href="/guides/macos.html" data-sveltekit-reload>{t('landing.nav.macmanual')}</a>
		<a href={UPGRADE_URL}>{t('landing.nav.pricing')}</a>
		<a href={APP_STORE_URL} rel="noopener">{t('landing.hero.cta.ios')}</a>
		<a href={PLAY_STORE_URL} rel="noopener">{t('landing.hero.cta.android')}</a>
		<a href="https://creapolis.dev/privacy-policy">{t('legal.privacy')}</a>
		<a href="https://creapolis.dev/terms-of-use">{t('legal.terms')}</a>
	</nav>
	<p class="fine">© 2026 Creapolis</p>
</footer>

<style>
	.foot {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-8) var(--space-4) calc(var(--space-8) + var(--safe-b));
		border-top: 1px solid var(--hairline);
	}

	.brand {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-weight: 800;
		color: var(--ink);
	}

	.foot-links {
		display: flex;
		align-items: center;
		gap: var(--space-2) var(--space-5);
		flex-wrap: wrap;
		justify-content: center;
	}

	.foot-links a {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.foot-links a:hover {
		color: var(--brand);
		text-decoration: none;
	}

	.fine {
		color: var(--faint);
		font-size: var(--text-xs);
	}
</style>
