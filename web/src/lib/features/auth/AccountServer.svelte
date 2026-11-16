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
		<p class="warn">✉️ {t('auth.verifyPending')}</p>
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
