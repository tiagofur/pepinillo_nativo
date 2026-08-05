<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t, LOCALES, type MessageKey } from '$lib/i18n/messages';
	import type { LocaleCode, ThemePreference } from '$lib/domain/entities/types';

	const locale = $derived(app.locale);

	let mode = $state<'login' | 'register'>('login');
	let email = $state('');
	let password = $state('');
	let name = $state('');

	function onLocale(e: Event) {
		const value = (e.currentTarget as HTMLSelectElement).value as LocaleCode;
		void app.updatePrefs({ locale: value });
	}

	function onTheme(e: Event) {
		const value = (e.currentTarget as HTMLSelectElement).value as ThemePreference;
		void app.updatePrefs({ theme: value });
	}

	function onWorkMinutes(e: Event) {
		const n = Number((e.currentTarget as HTMLInputElement).value);
		if (!Number.isFinite(n)) return;
		void app.updatePrefs({ pomodoroWorkMinutes: Math.min(90, Math.max(5, Math.round(n))) });
	}

	function onBreakMinutes(e: Event) {
		const n = Number((e.currentTarget as HTMLInputElement).value);
		if (!Number.isFinite(n)) return;
		void app.updatePrefs({ pomodoroBreakMinutes: Math.min(30, Math.max(1, Math.round(n))) });
	}

	async function onAuthSubmit(e: Event) {
		e.preventDefault();
		if (mode === 'login') {
			await app.login(email, password);
		} else {
			await app.register(email, name, password);
		}
	}

	function mapMsg(code: string | null): string {
		if (!code) return '';
		const known: MessageKey[] = [
			'sync.everywhereRequired',
			'sync.mergeExisting',
			'sync.ok',
			'auth.required'
		];
		if (known.includes(code as MessageKey)) return t(locale, code as MessageKey);
		return code;
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
			<strong class="profile-tier">
				{#if app.isSignedIn && app.canUseEverywhereSync}
					Everywhere
				{:else if app.isSignedIn}
					{t(locale, 'account.tierFree')} (account)
				{:else}
					{t(locale, 'account.tierFree')}
				{/if}
			</strong>
			{#if app.user}
				<span class="muted"
					>{t(locale, 'account.signedInAs')} {app.user.email}</span
				>
			{/if}
		</div>
	</div>

	<!-- Auth / sync (W2) -->
	<div class="settings-card card">
		{#if !app.apiConfigured}
			<p class="banner banner-warn" style="margin: 0;">{t(locale, 'account.apiMissing')}</p>
		{:else if !app.isSignedIn}
			<div class="row" style="margin-bottom: var(--space-3);">
				<button
					type="button"
					class="chip filter"
					class:active={mode === 'login'}
					onclick={() => (mode = 'login')}>{t(locale, 'account.signIn')}</button
				>
				<button
					type="button"
					class="chip filter"
					class:active={mode === 'register'}
					onclick={() => (mode = 'register')}>{t(locale, 'account.signUp')}</button
				>
			</div>
			<form class="stack" onsubmit={onAuthSubmit}>
				{#if mode === 'register'}
					<div class="field">
						<label for="name">{t(locale, 'account.name')}</label>
						<input id="name" type="text" bind:value={name} required autocomplete="name" />
					</div>
				{/if}
				<div class="field">
					<label for="email">{t(locale, 'account.email')}</label>
					<input
						id="email"
						type="email"
						bind:value={email}
						required
						autocomplete="email"
					/>
				</div>
				<div class="field">
					<label for="password">{t(locale, 'account.password')}</label>
					<input
						id="password"
						type="password"
						bind:value={password}
						required
						minlength="8"
						autocomplete={mode === 'login' ? 'current-password' : 'new-password'}
					/>
				</div>
				{#if app.authError}
					<p class="teaser" role="alert">{app.authError}</p>
				{/if}
				<button class="btn btn-primary btn-block" type="submit" disabled={app.authBusy}>
					{mode === 'login' ? t(locale, 'account.signIn') : t(locale, 'account.signUp')}
				</button>
			</form>
		{:else}
			{#if app.canUseEverywhereSync}
				<p class="banner banner-soft" style="margin-bottom: var(--space-3);">
					{t(locale, 'account.everywhereActive')}
				</p>
			{:else}
				<p class="teaser" style="margin-bottom: var(--space-3);">
					{t(locale, 'account.everywhereInactive')}
				</p>
			{/if}

			{#if app.mergeNotice}
				<p class="banner banner-warn">{mapMsg(app.mergeNotice)}</p>
			{/if}
			{#if app.lastSyncMessage}
				<p class="muted">{mapMsg(app.lastSyncMessage)}</p>
			{/if}

			<div class="stack">
				<button
					class="btn btn-primary btn-block"
					type="button"
					disabled={app.syncBusy || !app.canUseEverywhereSync}
					onclick={() => app.syncNow()}
				>
					{app.syncBusy ? t(locale, 'account.syncing') : t(locale, 'account.syncNow')}
				</button>
				<button
					class="btn btn-ghost btn-block"
					type="button"
					onclick={() => app.refreshProfile()}
				>
					{t(locale, 'account.refreshEntitlement')}
				</button>
				<button class="btn btn-ghost btn-block" type="button" onclick={() => app.logout()}>
					{t(locale, 'account.signOut')}
				</button>
			</div>
		{/if}
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

	<div class="settings-card card">
		<h2 class="section-title">{t(locale, 'account.pomodoro')}</h2>
		<div class="options-grid">
			<div class="field">
				<label for="work-min">{t(locale, 'account.workMinutes')}</label>
				<input
					id="work-min"
					type="number"
					min="5"
					max="90"
					value={app.prefs.pomodoroWorkMinutes}
					onchange={onWorkMinutes}
				/>
			</div>
			<div class="field">
				<label for="break-min">{t(locale, 'account.breakMinutes')}</label>
				<input
					id="break-min"
					type="number"
					min="1"
					max="30"
					value={app.prefs.pomodoroBreakMinutes}
					onchange={onBreakMinutes}
				/>
			</div>
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
		<p class="muted" style="margin: 0 0 var(--space-3);">
			{t(locale, 'account.deviceId')}:
			<code class="device-code">{app.deviceId || '…'}</code>
		</p>
		<p class="muted field-hint" style="margin-bottom: var(--space-3);">
			{t(locale, 'account.exportHint')}
		</p>
		<button class="btn btn-primary btn-block" type="button" onclick={() => app.exportLocalData()}>
			{t(locale, 'account.export')}
		</button>
	</div>

	<div class="settings-card card about-card">
		<p style="margin-bottom: var(--space-2);">{t(locale, 'account.about')}</p>
		<p class="muted" style="margin: 0;">{t(locale, 'account.nonGoals')}</p>
	</div>
</section>
