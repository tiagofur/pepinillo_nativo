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

<section class="panel">
	<div class="panel-head">
		<h1>{t(locale, 'account.title')}</h1>
	</div>

	<div class="stat">
		<span class="muted">{t(locale, 'account.tier')}</span>
		<strong style="font-size: var(--text-xl);">{t(locale, 'account.tierFree')}</strong>
	</div>

	<div class="field">
		<label for="locale">{t(locale, 'account.locale')}</label>
		<select id="locale" value={app.prefs.locale} onchange={onLocale}>
			{#each LOCALES as code (code)}
				<option value={code}>{code.toUpperCase()}</option>
			{/each}
		</select>
	</div>

	<div class="field">
		<label for="theme">{t(locale, 'account.theme')}</label>
		<select id="theme" value={app.prefs.theme} onchange={onTheme}>
			<option value="system">{t(locale, 'account.theme.system')}</option>
			<option value="light">{t(locale, 'account.theme.light')}</option>
			<option value="dark">{t(locale, 'account.theme.dark')}</option>
		</select>
		<p class="muted">Premium themes (Forest / Ocean / Sunset) require Everywhere.</p>
	</div>

	<p class="banner banner-warn">{t(locale, 'account.storageWarning')}</p>
	<p class="teaser">{t(locale, 'account.everywhereTeaser')}</p>

	<div class="stack">
		<p>{t(locale, 'account.about')}</p>
		<p class="muted">{t(locale, 'account.nonGoals')}</p>
		<p class="muted">
			{t(locale, 'account.deviceId')}:
			<code>{app.deviceId || '…'}</code>
		</p>
	</div>
</section>
