<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from './links';
</script>

<section class="final">
	<h2>{t('landing.cta.final.title')}</h2>
	<p>{t('landing.cta.final.body')}</p>
	<div class="cta-row">
		<a class="btn btn-primary pressable" href={WEB_APP_URL}>{t('landing.cta.web')}</a>
		<a class="btn btn-outline pressable" href={APP_STORE_URL} rel="noopener">{t('landing.hero.cta.ios')}</a>
		<a class="btn btn-outline pressable" href={PLAY_STORE_URL} rel="noopener">{t('landing.hero.cta.android')}</a>
	</div>
	<p class="hint">{t('landing.download.pikle')}</p>
</section>

<style>
	.final {
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-12) var(--space-4);
		border-radius: var(--radius-xl);
		background: var(--brand-softer);
	}

	.final h2 {
		font-size: var(--text-xl);
		letter-spacing: var(--tracking-tighter);
		max-width: 22ch;
		text-wrap: balance;
	}

	.final p {
		color: var(--muted);
		max-width: 44ch;
	}

	.cta-row {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
		margin-top: var(--space-2);
	}

	.hint {
		color: var(--faint);
		font-size: var(--text-xs);
	}
</style>
