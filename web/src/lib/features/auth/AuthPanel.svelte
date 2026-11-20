<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	/** OAuth por ID token del browser SDK (#946 S2/S3). Dormido sin Client
	 * IDs: nada de la sección (ni los scripts de google/apple) se carga. */
	const GOOGLE_CLIENT_ID = __PUBLIC_GOOGLE_CLIENT_ID__;
	const APPLE_CLIENT_ID = __PUBLIC_APPLE_CLIENT_ID__;
	const oauthAvailable = GOOGLE_CLIENT_ID !== '' || APPLE_CLIENT_ID !== '';
	let googleDiv = $state<HTMLDivElement | null>(null);
	let gisReady = $state(false);
	let oauthBusy = $state<'google' | 'apple' | null>(null);

	async function loadGis(): Promise<void> {
		if (gisReady || GOOGLE_CLIENT_ID === '') return;
		await new Promise<void>((resolve, reject) => {
			const s = document.createElement('script');
			s.src = 'https://accounts.google.com/gsi/client';
			s.async = true;
			s.onload = () => resolve();
			s.onerror = () => reject(new Error('gis_load_failed'));
			document.head.appendChild(s);
		});
		google.accounts.id.initialize({
			client_id: GOOGLE_CLIENT_ID,
			callback: async (response: { credential?: string }) => {
				if (!response.credential) return;
				oauthBusy = 'google';
				await auth.signInWithProvider('google', response.credential);
				oauthBusy = null;
			}
		});
		google.accounts.id.renderButton(googleDiv!, {
			theme: 'filled_black',
			size: 'large',
			shape: 'pill',
			text: 'signin_with'
		});
		gisReady = true;
	}

	async function signInApple(): Promise<void> {
		if (APPLE_CLIENT_ID === '') return;
		oauthBusy = 'apple';
		try {
			const AppleID: any = (window as any).AppleID;
			const authorization = await AppleID.auth.signIn();
			const idToken: string | undefined = authorization?.id_token;
			if (idToken) await auth.signInWithProvider('apple', idToken);
		} finally {
			oauthBusy = null;
		}
	}

	$effect(() => {
		if (oauthAvailable && GOOGLE_CLIENT_ID !== '') void loadGis();
		if (oauthAvailable && APPLE_CLIENT_ID !== '') {
			// Apple ID JS se carga diferido; inicializa al primer uso.
			const s = document.createElement('script');
			s.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js';
			s.async = true;
			document.head.appendChild(s);
		}
	});

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

		{#if oauthAvailable}
			<div class="oauth">
				{#if GOOGLE_CLIENT_ID !== ''}
					<div class="google-btn" bind:this={googleDiv}></div>
				{/if}
				{#if APPLE_CLIENT_ID !== ''}
					<button
						class="apple-btn pressable"
						type="button"
						disabled={oauthBusy !== null}
						onclick={signInApple}
					>
						{oauthBusy === 'apple' ? t('auth.working') : t('auth.oauth.apple')}
					</button>
				{/if}
				{#if auth.status === 'error' && auth.errorCode?.startsWith('oauth')}
					<p class="error">{t('auth.oauth.error')}</p>
				{/if}
			</div>
		{/if}

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

	.oauth {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		align-items: stretch;
	}

	.apple-btn {
		width: 100%;
		min-height: 44px;
		border-radius: var(--radius-pill);
		border: 1px solid var(--border-strong);
		background: #000;
		color: #fff;
		font-weight: 600;
		cursor: pointer;
	}

	.apple-btn:disabled {
		opacity: 0.6;
		cursor: default;
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
