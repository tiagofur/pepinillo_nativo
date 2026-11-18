<script lang="ts">
	import { page } from '$app/state';
	import { t } from '$lib/i18n/i18n.svelte';
</script>

<section class="error rise-in">
	<p class="code nums">{page.status}</p>
	<h1>{page.status === 404 ? t('error.notFound') : t('error.generic')}</h1>
	<p class="hint">{page.status === 404 ? t('error.notFoundHint') : t('error.genericHint')}</p>
	<a class="btn btn-primary pressable" href="/focus">{t('nav.focus')}</a>
</section>

<style>
	.error {
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-3);
		text-align: center;
		padding: var(--space-8);
	}

	.code {
		font-family: var(--font-rounded);
		font-size: var(--text-xl);
		font-weight: 650;
		color: var(--brand);
		margin: 0;
	}

	h1 {
		font-size: var(--text-lg);
		letter-spacing: var(--tracking-tight);
		margin: 0;
	}

	.hint {
		color: var(--muted);
		font-size: var(--text-sm);
		max-width: 42ch;
		margin-bottom: var(--space-4);
	}
</style>
