<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t, LOCALES } from '$lib/i18n/messages';
	import type { LocaleCode, ThemePreference } from '$lib/domain/entities/types';

	const locale = $derived(app.locale);

	function onLocale(e: Event) {
		const value = (e.currentTarget as HTMLSelectElement).value as LocaleCode;
		void app.updatePrefs({ locale: value });
	}

	function onTheme(e: Event) {
		const value = (e.currentTarget as HTMLSelectElement).value as ThemePreference;
		void app.updatePrefs({ theme: value });
	}
</script>

<section class="panel account-screen">
	<div class="panel-head">
		<div>
			<h1>{t(locale, 'account.title')}</h1>
			<p class="muted panel-sub">{t(locale, 'account.subtitle')}</p>
		</div>
	</div>

	<div class="profile-card card">
		<div class="avatar" aria-hidden="true">P</div>
		<div class="profile-text">
			<span class="muted">{t(locale, 'account.tier')}</span>
			<strong class="profile-tier">{t(locale, 'account.tierFree')}</strong>
		</div>
	</div>

	<div class="settings-card card">
		<h2 class="section-title">{t(locale, 'account.settings')}</h2>
		<div class="field">
			<label for="locale">{t(locale, 'account.locale')}</label>
			<select id="locale" value={app.prefs.locale} onchange={onLocale}>
				{#each LOCALES as code (code)}
					<option value={code}>{code.toUpperCase()}</option>
				{/each}
			</select>
		</div>
		<div class="field" style="margin-bottom: 0;">
			<label for="theme">{t(locale, 'account.theme')}</label>
			<select id="theme" value={app.prefs.theme} onchange={onTheme}>
				<option value="system">{t(locale, 'account.theme.system')}</option>
				<option value="light">{t(locale, 'account.theme.light')}</option>
				<option value="dark">{t(locale, 'account.theme.dark')}</option>
			</select>
			<p class="muted field-hint">{t(locale, 'account.premiumThemes')}</p>
		</div>
	</div>

	<div class="upgrade-card card">
		<span class="upgrade-kicker">{t(locale, 'account.upgradeTitle')}</span>
		<p class="teaser-inline">{t(locale, 'account.everywhereTeaser')}</p>
	</div>

	<div class="settings-card card">
		<h2 class="section-title">{t(locale, 'account.storage')}</h2>
		<p class="banner banner-warn" style="margin-bottom: var(--space-3);">
			{t(locale, 'account.storageWarning')}
		</p>
		<p class="muted" style="margin: 0;">
			{t(locale, 'account.deviceId')}:
			<code class="device-code">{app.deviceId || '…'}</code>
		</p>
	</div>

	<div class="settings-card card about-card">
		<p style="margin-bottom: var(--space-2);">{t(locale, 'account.about')}</p>
		<p class="muted" style="margin: 0;">{t(locale, 'account.nonGoals')}</p>
	</div>
</section>
