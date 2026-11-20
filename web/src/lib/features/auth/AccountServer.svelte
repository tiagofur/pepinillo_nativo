<script lang="ts">
	import Sheet from '$lib/design/Sheet.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { listAllTasks, listSessions } from '$lib/data/local/idb';
	import type { Task } from '$lib/domain/entities/types';

	const TIER_LABELS: Record<string, string> = {
		free: 'Free',
		pepinillo_plus: 'Pepinillo+',
		everywhere_monthly: 'Everywhere/AI+',
		everywhere_annual: 'Everywhere/AI+'
	};

	let confirmDelete = $state(false);
	let deleteEmail = $state('');
	let noticeText = $state('');

	// Change password (#946 S1).
	let pwCurrent = $state('');
	let pwNew = $state('');
	let pwConfirm = $state('');
	let pwState = $state<'idle' | 'working' | 'done' | 'wrong' | 'weak' | 'mismatch' | 'error'>('idle');

	async function submitPassword(e: SubmitEvent): Promise<void> {
		e.preventDefault();
		if (pwState === 'working') return;
		if (pwNew !== pwConfirm) {
			pwState = 'mismatch';
			return;
		}
		pwState = 'working';
		const r = await auth.changePassword(pwCurrent, pwNew);
		if (r === 'ok') {
			pwState = 'done';
			pwCurrent = pwNew = pwConfirm = '';
		} else {
			pwState = r;
		}
	}

	// Email verification (#944): 6-digit code from the notification email.
	let verifyCode = $state('');
	let verifyState = $state<'idle' | 'working' | 'done' | 'invalid' | 'already' | 'error'>('idle');
	let resendState = $state<'idle' | 'working' | 'sent' | 'error'>('idle');

	async function submitVerify(e: SubmitEvent): Promise<void> {
		e.preventDefault();
		if (!verifyCode.trim() || verifyState === 'working') return;
		verifyState = 'working';
		const r = await auth.verifyEmail(verifyCode.trim());
		verifyState =
			r === 'ok' ? 'done' : r === 'invalid' ? 'invalid' : r === 'verified' ? 'already' : 'error';
		if (r === 'ok') verifyCode = '';
	}
	async function resend(): Promise<void> {
		resendState = 'working';
		resendState = await auth.resendVerification() ? 'sent' : 'error';
	}

	function fmtWhen(iso: string | null): string {
		if (!iso) return '—';
		return new Date(iso).toLocaleString([], { dateStyle: 'short', timeStyle: 'short' });
	}

	function download(name: string, content: string, mime: string): void {
		const blob = new Blob([content], { type: mime });
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = name;
		a.click();
		URL.revokeObjectURL(url);
	}

	async function exportCsv(): Promise<void> {
		const [tasks, sessions] = await Promise.all([listAllTasks(), listSessions()]);
		const rows: string[] = ['type,id,title_or_mode,status,extra,iso_date'];
		for (const tk of tasks as Task[]) {
			rows.push(
				`task,"${tk.id}","${tk.title.replaceAll('"', '""')}",${tk.status},${tk.completedPomodoros ?? 0}/${tk.estimatedPomodoros},"${tk.createdAt}"`
			);
		}
		for (const s of sessions) {
			rows.push(
				`session,"${s.id}","${s.mode}",${s.status},${Math.round(s.elapsedMs / 1000)}s,"${s.startedAt ?? ''}"`
			);
		}
		download('pepinillo-export.csv', rows.join('\n'), 'text/csv');
	}

	async function exportJson(): Promise<void> {
		const [tasks, sessions, prefs] = await Promise.all([
			listAllTasks(),
			listSessions(),
			import('$lib/data/local/idb').then((m) => m.getPreferences())
		]);
		download(
			'pepinillo-export.json',
			JSON.stringify({ tasks, sessions, prefs, exportedAt: new Date().toISOString() }, null, 2),
			'application/json'
		);
	}

	async function deleteAccount(): Promise<void> {
		const ok = await auth.deleteAccount();
		if (ok) {
			confirmDelete = false;
			deleteEmail = '';
		} else {
			noticeText = t('auth.deleteFailed');
			setTimeout(() => (noticeText = ''), 4000);
		}
	}
</script>

<div class="card section profile">
	<div class="who">
		<div class="avatar">{auth.user?.name?.[0]?.toUpperCase() ?? '?'}</div>
		<div class="ident">
			<span class="name">{auth.user?.name}</span>
			<span class="email muted">{auth.user?.email}</span>
		</div>
		<span class="badge">{TIER_LABELS[auth.user?.subscriptionTier ?? 'free'] ?? auth.user?.subscriptionTier}</span>
	</div>
	{#if auth.user && !auth.user.emailVerified}
		<div class="verify" role="region" aria-label={t('auth.verifyPending')}>
			<p class="warn">✉️ {t('auth.verifyPending')}</p>
			{#if verifyState === 'done'}
				<p class="verify-ok" role="status">✅ {t('auth.verify.done')}</p>
			{:else}
				<form class="verify-form" onsubmit={submitVerify}>
					<input
						class="field"
						inputmode="numeric"
						pattern="[0-9]*"
						placeholder={t('auth.verify.codeField')}
						bind:value={verifyCode}
						autocomplete="one-time-code"
					/>
					<button class="btn btn-primary pressable" type="submit" disabled={verifyState === 'working'}>
						{verifyState === 'working' ? t('auth.working') : t('auth.verify.submit')}
					</button>
					<button
						class="btn btn-ghost pressable"
						type="button"
						disabled={auth.resendCooldown > 0 || resendState === 'working'}
						onclick={resend}
					>
						{auth.resendCooldown > 0
							? t('auth.verify.resendIn', { s: auth.resendCooldown })
							: resendState === 'working'
								? t('auth.working')
								: t('auth.verify.resend')}
					</button>
				</form>
				{#if resendState === 'sent'}
					<p class="verify-note" role="status">{t('auth.verify.resent')}</p>
				{:else if resendState === 'error'}
					<p class="verify-bad" role="alert">{t('auth.verify.errorGeneric')}</p>
				{/if}
				{#if verifyState === 'invalid'}
					<p class="verify-bad" role="alert">{t('auth.verify.invalid')}</p>
				{:else if verifyState === 'already'}
					<p class="verify-note" role="status">{t('auth.verify.already')}</p>
				{:else if verifyState === 'error'}
					<p class="verify-bad" role="alert">{t('auth.verify.errorGeneric')}</p>
				{/if}
			{/if}
		</div>
	{/if}
</div>

<div class="card section">
	<h2>☁️ {t('sync.title')}</h2>
	<p class="muted">{t('sync.hint')}</p>
	<div class="sync-row">
		<button class="btn btn-primary pressable" disabled={auth.syncing} onclick={() => auth.syncNow()}>
			{auth.syncing ? t('account.syncing') : t('account.syncNow')}
		</button>
		<span class="muted nums">{t('sync.last')}: {fmtWhen(auth.lastSyncAt)}</span>
	</div>
	<p class="muted status">
		<span class="dot" class:on={auth.wsConnected}></span>
		{auth.wsConnected ? t('sync.live') : t('sync.offline')}
		{#if auth.lastSyncError}
			· <span class="err">{auth.lastSyncError}</span>
		{/if}
	</p>
	{#if auth.lastSyncError === 'ERR_DEVICE_BOUND'}
		<p class="device-bound" role="alert">
			🔒 {t('sync.deviceBound')}
			<a href="/upgrade">{t('plan.upgradeCta')} →</a>
		</p>
	{/if}
</div>

<div class="card section">
	<h2>🔑 {t('auth.password.title')}</h2>
	<form class="pw-form" onsubmit={submitPassword}>
		<input
			class="field"
			type="password"
			placeholder={t('auth.password.current')}
			bind:value={pwCurrent}
			autocomplete="current-password"
			required
		/>
		<input
			class="field"
			type="password"
			placeholder={t('auth.password.new')}
			bind:value={pwNew}
			minlength="8"
			autocomplete="new-password"
			required
		/>
		<input
			class="field"
			type="password"
			placeholder={t('auth.password.confirm')}
			bind:value={pwConfirm}
			autocomplete="new-password"
			required
		/>
		<button class="btn btn-primary pressable" type="submit" disabled={pwState === 'working'}>
			{pwState === 'working' ? t('auth.password.working') : t('auth.password.submit')}
		</button>
	</form>
	{#if pwState === 'done'}
		<p class="pw-msg ok" role="status">✅ {t('auth.password.done')}</p>
	{:else if pwState === 'wrong'}
		<p class="pw-msg bad" role="alert">{t('auth.password.wrong')}</p>
	{:else if pwState === 'weak'}
		<p class="pw-msg bad" role="alert">{t('auth.password.weak')}</p>
	{:else if pwState === 'mismatch'}
		<p class="pw-msg bad" role="alert">{t('auth.password.mismatch')}</p>
	{:else if pwState === 'error'}
		<p class="pw-msg bad" role="alert">{t('auth.password.errorGeneric')}</p>
	{/if}
</div>

<div class="card section">
	<h2>📦 {t('account.export')}</h2>
	<p class="muted">{t('account.exportHint')}</p>
	<div class="row">
		<button class="btn btn-outline pressable" onclick={exportCsv}>CSV</button>
		<button
			class="btn btn-outline pressable"
			class:is-locked={app.tier === 'free'}
			disabled={app.tier === 'free'}
			onclick={exportJson}
			title={app.tier === 'free' ? t('common.proLocked') : ''}
		>
			{#if app.tier === 'free'}🔒{/if} JSON
		</button>
	</div>
</div>

<div class="card section danger">
	<h2>{t('auth.dangerTitle')}</h2>
	{#if confirmDelete}
		<p class="warn">{t('auth.deleteConfirm')}</p>
		<input class="field" type="email" placeholder={t('auth.emailField')} bind:value={deleteEmail} />
		{#if noticeText}
			<p class="notice">{noticeText}</p>
		{/if}
		<div class="row">
			<button class="btn pressable danger-btn" disabled={deleteEmail !== auth.user?.email} onclick={deleteAccount}>
				{t('auth.deleteAccount')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => (confirmDelete = false)}>{t('journal.skip')}</button>
		</div>
	{:else}
		<div class="row">
			<button class="btn btn-outline pressable" onclick={() => auth.signOut()}>{t('account.signOut')}</button>
			<button class="btn btn-ghost pressable danger-btn" onclick={() => (confirmDelete = true)}>
				{t('auth.deleteAccount')}
			</button>
		</div>
	{/if}
</div>

<!-- Merge dialog: server has data, what wins? -->
<Sheet open={auth.mergeOpen} onclose={() => (auth.mergeOpen = false)} title={t('sync.mergeTitle')}>
	<p class="muted">{t('sync.mergeBody')}</p>
	<div class="merge-choices">
		<button class="btn btn-primary pressable" onclick={() => auth.resolveMerge('pull')}>
			{t('sync.mergePull')}
		</button>
		<button class="btn btn-outline pressable" onclick={() => auth.resolveMerge('upload')}>
			{t('sync.mergeUpload')}
		</button>
	</div>
</Sheet>

<style>
	.section {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	h2 {
		font-size: var(--text-base);
		font-weight: 650;
	}

	.muted {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.profile .who {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.avatar {
		width: 44px;
		height: 44px;
		border-radius: 50%;
		background: var(--brand-soft);
		color: var(--brand);
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 800;
		font-size: var(--text-md);
	}

	.ident {
		display: flex;
		flex-direction: column;
		flex: 1;
		min-width: 0;
	}

	.name {
		font-weight: 650;
	}

	.email {
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.warn {
		color: var(--streak);
		font-size: var(--text-sm);
		font-weight: 550;
	}

	.pw-form {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.pw-msg {
		margin: 0;
		font-size: var(--text-sm);
	}

	.pw-msg.ok {
		color: var(--brand);
		font-weight: 650;
	}

	.pw-msg.bad {
		color: var(--mode-pomodoro);
		font-weight: 550;
	}

	.verify {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.verify-form {
		display: flex;
		gap: var(--space-2);
		flex-wrap: wrap;
		align-items: center;
	}

	.verify-form .field {
		flex: 1;
		min-width: 180px;
		font-variant-numeric: tabular-nums;
		letter-spacing: 0.12em;
	}

	.verify-ok {
		margin: 0;
		color: var(--brand);
		font-weight: 650;
		font-size: var(--text-sm);
	}

	.verify-note {
		margin: 0;
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.verify-bad {
		margin: 0;
		color: var(--mode-pomodoro);
		font-size: var(--text-sm);
		font-weight: 550;
	}

	.sync-row {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		flex-wrap: wrap;
	}

	.status {
		display: flex;
		align-items: center;
		gap: var(--space-2);
	}

	.dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: var(--faint);
	}

	.dot.on {
		background: var(--brand);
		box-shadow: var(--ring-glow);
	}

	.err {
		color: var(--mode-pomodoro);
	}

	.device-bound {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		flex-wrap: wrap;
		margin: 0;
		color: var(--mode-pomodoro);
		font-size: var(--text-sm);
		font-weight: 600;
	}

	.device-bound a {
		color: var(--brand);
		font-weight: 650;
	}

	.row {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	.danger-btn {
		color: var(--mode-pomodoro);
	}

	.merge-choices {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-top: var(--space-3);
	}
</style>
