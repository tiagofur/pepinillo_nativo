<script lang="ts">
	import { onMount } from 'svelte';
	import { app, PREMIUM_THEMES, type ThemeName } from '$lib/stores/app.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { LOCALES, type MessageKey } from '$lib/i18n/messages';
	import Icon from '$lib/design/Icon.svelte';
	import FocusSettings from '$lib/features/settings/FocusSettings.svelte';
	import Segmented from '$lib/design/Segmented.svelte';
	import PaneToolbar from '$lib/features/shell/PaneToolbar.svelte';
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
	<PaneToolbar title={t('account.title')} />
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
		<Segmented
			options={LOCALES.map((code) => ({ id: code, label: LOCALE_LABELS[code] }))}
			value={app.prefs.locale}
			onchange={(id) => app.setLocaleOf(id as LocaleCode)}
		/>
	</div>

	<div class="card section">
		<h2>{t('account.appearance')}</h2>
		<Segmented
			options={APPEARANCES.map((a) => ({ id: a, label: t(appearanceKey(a)) }))}
			value={app.prefs.theme}
			onchange={(id) => app.setAppearance(id as ThemePreference)}
		/>
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
		{#if app.storagePersisted !== null}
			<p class="storage-state" aria-live="polite">
				{app.storagePersisted ? '✅' : '⚠️'} {t('account.storage')}:
				{app.storagePersisted
					? t('account.storage.persisted')
					: t('account.storage.bestEffort')}
			</p>
		{/if}
	</div>

	<div id="settings" class="settings-anchor"><FocusSettings /></div>
	<a class="guides-link pressable" href="/guides">
		📖 {t('landing.nav.guides')} →
	</a>
</section>

<style>
	.account {
		max-width: 640px;
		margin-inline: auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-5);
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
	.guides-link {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		padding: var(--space-3) var(--space-4);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface);
		color: var(--brand);
		font-weight: 650;
		font-size: var(--text-sm);
	}

	.guides-link:hover {
		text-decoration: none;
		border-color: var(--brand);
	}
</style>
