<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import type { Achievement } from '$lib/domain/achievements/achievements';
	import type { FocusSession, Task } from '$lib/domain/entities/types';
	import Icon from '$lib/design/Icon.svelte';

	let {
		achievements,
		sessions,
		tasks,
		nextTask,
		onstart,
		onopenplan
	}: {
		achievements: Achievement[];
		sessions: FocusSession[];
		tasks: Task[];
		nextTask: Task | null;
		onstart: (task: Task | null) => void;
		onopenplan: () => void;
	} = $props();

	const ACH_EMOJI: Record<string, string> = {
		firstFocus: '🌱',
		weekWarrior: '🗓️',
		pomodoroMaster: '🍅',
		deepDiver: '🤿',
		centuryClub: '💯',
		earlyBird: '🌅'
	};

	// Mac session rows: mode-colored icon before the mode name.
	const MODE_COLOR: Record<string, string> = {
		pomodoro: 'var(--mode-pomodoro)',
		flowtime: 'var(--mode-flowtime)',
		timeblock: 'var(--mode-timeblock)',
		stopwatch: 'var(--mode-stopwatch)'
	};

	// Mac rows: cap 5 ("Últimas 5"), linked task title, "Detenida" badge
	// for incomplete sessions (MacTodayView.recentSessionsCard).
	const CAP = 5;

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	function timeOf(s: FocusSession): string {
		return new Date(s.startedAt ?? '').toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}

	function taskTitle(s: FocusSession): string | null {
		if (!s.taskId) return null;
		return tasks.find((x) => x.id === s.taskId)?.title ?? null;
	}
</script>

{#snippet nextFocusCard()}
	<div class="card panel">
		<h3 class="nf-head">
			<Icon name="play" size={15} />
			{t('dash.nextFocus.title')}
		</h3>
		{#if nextTask}
			<div class="nf-task">
				<span
					class="nf-dot"
					style="background: {nextTask.energy === 'deep'
						? 'var(--brand)'
						: nextTask.energy === 'shallow'
							? 'var(--mode-flowtime)'
							: 'var(--streak)'}"
					aria-hidden="true"
				></span>
				<div class="nf-meta">
					<p class="nf-title">{nextTask.title}</p>
					<p class="nf-pomos nums">{t('dash.nextFocus.pomodoros', { n: nextTask.estimatedPomodoros })}</p>
				</div>
			</div>
		{:else}
			<div class="nf-task">
				<div class="nf-meta">
					<p class="nf-title">{t('dash.nextFocus.empty.title')}</p>
					<p class="nf-pomos">{t('dash.nextFocus.empty.body')}</p>
				</div>
			</div>
		{/if}
		<button class="btn btn-primary pressable nf-cta" onclick={() => onstart(nextTask)}>
			<Icon name="play" size={15} />
			{t('dash.nextFocus.start')}
		</button>
		{#if !nextTask}
			<button class="nf-plan pressable" onclick={onopenplan}>{t('dash.nextFocus.openPlan')}</button>
		{/if}
	</div>
{/snippet}

{#snippet sessionsPanel()}
	<div class="card panel">
		<h3 class="panel-head">
			{t('sessions.recent')}
			{#if sessions.length > 0}
				<span class="last5">{t('sessions.last5')}</span>
			{/if}
		</h3>
		{#if sessions.length === 0}
			<p class="muted strong">{t('sessions.empty')}</p>
			<p class="muted">{t('sessions.empty.desc')}</p>
		{:else}
			<ul class="sessions">
				{#each sessions.slice(0, CAP) as s (s.id)}
					<li class="session-row">
						<span class="s-dot" style="background: {MODE_COLOR[s.mode]}" aria-hidden="true"></span>
						<span class="s-mode">{t(`focus.mode.${s.mode}` as MessageKey)}</span>
						<span class="s-time nums">{timeOf(s)} · {fmtMin(s.elapsedMs / 1000)}</span>
						{#if taskTitle(s)}
							<span class="s-task">{taskTitle(s)}</span>
						{/if}
						{#if s.status !== 'completed'}
							<span class="s-stopped">{t('sessions.stopped')}</span>
						{/if}
					</li>
				{/each}
			</ul>
		{/if}
	</div>
{/snippet}

{#snippet achievementsRow()}
	<div class="card panel">
		<h3>{t('achievements.title')}</h3>
		<div class="ach-row">
			{#each achievements as a (a.id)}
				<button
					class="ach pressable"
					class:unlocked={a.unlocked}
					title={t(`achievements.${a.id}.title` as MessageKey)}
				>
					<span class="ach-emoji">{ACH_EMOJI[a.id]}</span>
					<span class="ach-name">{t(`achievements.${a.id}.title` as MessageKey)}</span>
					{#if !a.unlocked}
						<span class="ach-progress nums">{Math.round(a.progress * 100)}%</span>
					{/if}
				</button>
			{/each}
		</div>
	</div>
{/snippet}

<div class="panels">
	{@render sessionsPanel()}
	{@render nextFocusCard()}
	{@render achievementsRow()}
</div>

<style>
	/* Mac Today: recent sessions + next-focus columns, adaptive grid min 320 */
	.panels {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(min(320px, 100%), 1fr));
		gap: var(--space-6);
		align-items: start;
	}

	.panel {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	h3 {
		font-size: var(--text-sm);
		font-weight: 700;
		color: var(--muted);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.panel-head {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: var(--space-3);
	}

	.last5 {
		font-size: var(--text-2xs);
		font-weight: 600;
		text-transform: none;
		letter-spacing: 0;
		color: var(--faint);
	}

	.muted {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.muted.strong {
		font-weight: 650;
		color: var(--ink-secondary);
	}

	/* ---- Next Focus (Mac nextFocusCard) ---- */
	.nf-head {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		text-transform: none;
		letter-spacing: 0;
		font-size: var(--text-base);
		color: var(--ink);
	}

	.nf-head :global(svg) {
		color: var(--brand);
	}

	.nf-task {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
	}

	.nf-dot {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		margin-top: 6px;
		flex: none;
	}

	.nf-meta {
		min-width: 0;
	}

	.nf-title {
		margin: 0;
		font-weight: 600;
		font-size: var(--text-base);
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.nf-pomos {
		margin: var(--space-1) 0 0;
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.nf-cta {
		justify-content: center;
	}

	.nf-plan {
		border: none;
		background: none;
		color: var(--brand);
		font-weight: 600;
		font-size: var(--text-sm);
		cursor: pointer;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-sm);
		align-self: flex-start;
	}

	.nf-plan:hover {
		background: var(--brand-softer);
	}

	/* ---- Recent sessions ---- */
	.sessions {
		list-style: none;
		margin: 0;
		padding: 0;
		display: flex;
		flex-direction: column;
	}

	.session-row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: 44px;
		border-top: 1px solid var(--hairline);
		font-size: var(--text-sm);
	}

	.session-row:first-child {
		border-top: none;
	}

	.s-dot {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		flex: none;
	}

	.s-mode {
		font-weight: 600;
		color: var(--ink-secondary);
		flex: none;
	}

	.s-time {
		color: var(--muted);
		flex: none;
	}

	.s-task {
		color: var(--faint);
		font-size: var(--text-xs);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		flex: 1;
		text-align: end;
	}

	.s-stopped {
		flex: none;
		font-size: var(--text-2xs);
		font-weight: 650;
		color: var(--mode-pomodoro);
		background: var(--mode-pomodoro-soft);
		border-radius: var(--radius-pill);
		padding: 2px 8px;
	}
</style>
