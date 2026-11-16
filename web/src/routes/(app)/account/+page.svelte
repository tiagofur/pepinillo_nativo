<script lang="ts">
	import { onMount } from 'svelte';
	import { app, PREMIUM_THEMES, type ThemeName } from '$lib/stores/app.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { LOCALES, type MessageKey } from '$lib/i18n/messages';
	import Icon from '$lib/design/Icon.svelte';
	import FocusSettings from '$lib/features/settings/FocusSettings.svelte';
	import AuthPanel from '$lib/features/auth/AuthPanel.svelte';
	import AccountServer from '$lib/features/auth/AccountServer.svelte';
	import type { LocaleCode, ThemePreference } from '$lib/domain/entities/types';

	onMount(() => {
		void auth.init();
	});

	const LOCALE_LABELS: Record<LocaleCode, string> = {
		es: 'Español',
		en: 'English',
		pt: 'Português'
	};

	const THEMES: { id: ThemeName; key: MessageKey }[] = [
		{ id: 'classic', key: 'account.theme.classic' },
		{ id: 'forest', key: 'account.theme.forest' },
		{ id: 'ocean', key: 'account.theme.ocean' },
		{ id: 'sunset', key: 'account.theme.sunset' }
	];

	const APPEARANCES: ThemePreference[] = ['system', 'light', 'dark'];

	function appearanceKey(a: ThemePreference): MessageKey {
		if (a === 'system') return 'account.theme.system';
		if (a === 'light') return 'account.theme.light';
		return 'account.theme.dark';
	}
</script>

<svelte:head>
	<title>{t('account.settings')} · Pepinillo</title>
</svelte:head>

<section class="account rise-in">
	<h1>{t('account.title')}</h1>
	<p class="subtitle">{t('account.subtitle')}</p>

	{#if auth.configured}
		{#if auth.user}
			<AccountServer />
		{:else}
			<AuthPanel />
		{/if}
	{:else}
		<div class="card section">
			<p class="muted">🔌 {t('auth.apiMissing')}</p>
		</div>
	{/if}

	<div class="card section">
		<h2>{t('account.locale')}</h2>
		<div class="row">
			{#each LOCALES as code (code)}
				<button
					class="chip pressable"
					aria-pressed={app.prefs.locale === code}
					class:is-active={app.prefs.locale === code}
					onclick={() => app.setLocaleOf(code)}
				>
					{LOCALE_LABELS[code]}
				</button>
			{/each}
		</div>
	</div>

	<div class="card section">
		<h2>{t('account.appearance')}</h2>
		<div class="row">
			{#each APPEARANCES as a (a)}
				<button
					class="chip pressable"
					aria-pressed={app.prefs.theme === a}
					class:is-active={app.prefs.theme === a}
					onclick={() => app.setAppearance(a)}
				>
					{t(appearanceKey(a))}
				</button>
			{/each}
		</div>
	</div>

	<div class="card section">
		<h2>{t('account.theme')}</h2>
		<div class="row">
			{#each THEMES as th (th.id)}
				{@const locked = PREMIUM_THEMES.includes(th.id) && !app.canUseTheme(th.id)}
				<button
					class="chip pressable"
					aria-pressed={app.theme === th.id}
					class:is-active={app.theme === th.id}
					class:is-locked={locked}
					disabled={locked}
					onclick={() => app.setTheme(th.id)}
				>
					{#if locked}<Icon name="lock" size={14} />{/if}
					{t(th.key)}
				</button>
			{/each}
		</div>
		<p class="hint">{t('account.premiumThemes')}</p>
	</div>

	<div class="card section meta">
		<h2>{t('account.deviceId')}</h2>
		<code class="mono nums">{app.deviceId ?? '—'}</code>
	</div>

	<FocusSettings />
</section>

<style>
	.account {
		max-width: 640px;
		margin-inline: auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
		padding-top: var(--space-8);
	}

	h1 {
		font-size: var(--text-xl);
	}

	h2 {
		font-size: var(--text-base);
		font-weight: 650;
	}

	.subtitle {
		color: var(--muted);
		margin-top: calc(-1 * var(--space-3));
	}

	.section {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.hint {
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.meta code {
		font-size: var(--text-xs);
		color: var(--muted);
		word-break: break-all;
	}
</style>
