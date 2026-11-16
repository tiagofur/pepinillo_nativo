<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	type Mode = 'signIn' | 'signUp' | 'forgot';
	let mode = $state<Mode>('signIn');
	let email = $state('');
	let name = $state('');
	let password = $state('');
	let notice = $state('');

	const ERROR_KEYS: Record<string, MessageKey> = {
		invalid_credentials: 'auth.error.invalidCredentials',
		invalid_email: 'auth.error.invalidEmail',
		email_taken: 'auth.error.emailTaken',
		weak_password: 'auth.error.weakPassword',
		api_not_configured: 'auth.error.apiMissing'
	};

	let errorText = $derived.by(() => {
		const code = auth.errorCode;
		if (!code) return '';
		const key = ERROR_KEYS[code];
		return key ? t(key) : t('auth.error.generic');
	});

	async function submit(e: SubmitEvent): Promise<void> {
		e.preventDefault();
		notice = '';
		if (mode === 'signIn') {
			await auth.signIn(email, password);
		} else if (mode === 'signUp') {
			await auth.signUp(email, name, password);
		} else {
			const ok = await auth.forgotPassword(email);
			notice = ok ? t('auth.forgot.sent') : t('auth.error.generic');
		}
	}

	function switchMode(next: Mode): void {
		mode = next;
		auth.errorCode = null;
		notice = '';
	}
</script>

<div class="card auth">
	<h2>🔐 {t('auth.title')}</h2>
	<p class="muted">{t('auth.subtitle')}</p>

	<form class="form" onsubmit={submit}>
		{#if mode === 'signUp'}
			<input class="field" type="text" placeholder={t('auth.nameField')} bind:value={name} required />
		{/if}
		<input class="field" type="email" placeholder={t('auth.emailField')} bind:value={email} required />
		{#if mode !== 'forgot'}
			<input class="field" type="password" placeholder={t('auth.passwordField')} bind:value={password} minlength="8" required />
		{/if}

		{#if auth.status === 'error' && errorText}
			<p class="error">{errorText}</p>
		{/if}
		{#if notice}
			<p class="notice">{notice}</p>
		{/if}

		<button class="btn btn-primary pressable" type="submit" disabled={auth.status === 'loading'}>
			{#if auth.status === 'loading'}
				{t('auth.working')}
			{:else if mode === 'signIn'}
				{t('auth.signIn')}
			{:else if mode === 'signUp'}
				{t('auth.signUp')}
			{:else}
				{t('auth.forgot.submit')}
			{/if}
		</button>
	</form>

	<div class="links">
		{#if mode === 'signIn'}
			<button class="link" onclick={() => switchMode('signUp')}>{t('auth.needAccount')}</button>
			<button class="link" onclick={() => switchMode('forgot')}>{t('auth.forgot.link')}</button>
		{:else}
			<button class="link" onclick={() => switchMode('signIn')}>{t('auth.haveAccount')}</button>
		{/if}
	</div>

	<p class="hint">{t('auth.syncHint')}</p>
</div>

<style>
	.auth {
		padding: var(--space-6);
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	h2 {
		font-size: var(--text-lg);
	}

	.muted,
	.hint {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.hint {
		font-size: var(--text-xs);
		color: var(--faint);
	}

	.form {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.error {
		color: var(--mode-pomodoro);
		font-size: var(--text-sm);
		font-weight: 550;
	}

	.notice {
		color: var(--brand);
		font-size: var(--text-sm);
		font-weight: 550;
	}

	.links {
		display: flex;
		gap: var(--space-4);
	}

	.link {
		background: none;
		border: none;
		color: var(--brand);
		font-weight: 600;
		cursor: pointer;
		padding: 0;
		min-height: 44px;
	}

	.link:hover {
		text-decoration: underline;
	}
</style>
