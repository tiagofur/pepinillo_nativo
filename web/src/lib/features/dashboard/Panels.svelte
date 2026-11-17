<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import type { Achievement } from '$lib/domain/achievements/achievements';
	import type { FocusSession } from '$lib/domain/entities/types';

	let { achievements, sessions }: { achievements: Achievement[]; sessions: FocusSession[] } = $props();

	const ACH_EMOJI: Record<string, string> = {
		firstFocus: '🌱',
		weekWarrior: '🗓️',
		pomodoroMaster: '🍅',
		deepDiver: '🤿',
		centuryClub: '💯',
		earlyBird: '🌅'
	};

	const RATING_FACES: Record<number, string> = { 1: '😞', 2: '😐', 3: '🙂', 4: '😊', 5: '🔥' };

	// Mac session rows: 24pt mode-colored icon before the mode name.
	const MODE_COLOR: Record<string, string> = {
		pomodoro: 'var(--mode-pomodoro)',
		flowtime: 'var(--mode-flowtime)',
		timeblock: 'var(--mode-timeblock)',
		stopwatch: 'var(--mode-stopwatch)'
	};

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	function timeOf(s: FocusSession): string {
		return new Date(s.startedAt ?? '').toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
	}
</script>

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

{#snippet sessionsPanel()}
	<div class="card panel">
		<h3>{t('sessions.recent')}</h3>
		{#if sessions.length === 0}
			<p class="muted">{t('sessions.empty')}</p>
		{:else}
			<ul class="sessions">
				{#each sessions.slice(0, 8) as s (s.id)}
					<li class="session-row">
						<span class="s-dot" style="background: {MODE_COLOR[s.mode]}" aria-hidden="true"></span>
						<span class="s-mode">{t(`focus.mode.${s.mode}` as MessageKey)}</span>
						<span class="s-time nums">{timeOf(s)} · {fmtMin(s.elapsedMs / 1000)}</span>
						{#if s.journal}
							<span class="s-journal">{s.journal}</span>
						{/if}
					</li>
				{/each}
			</ul>
		{/if}
	</div>
{/snippet}

<div class="panels">
	{@render achievementsRow()}
	{@render sessionsPanel()}
</div>

<style>
	/* Mac Today: recent sessions + next-focus columns, adaptive grid min 320 */
	.panels {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
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

	.muted {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.ach-row {
		display: flex;
		gap: var(--space-2);
		overflow-x: auto;
		padding-bottom: var(--space-1);
	}

	.ach {
		flex: none;
		width: 92px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		padding: var(--space-3) var(--space-2);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface-alt);
		opacity: 0.55;
		cursor: default;
	}

	.ach.unlocked {
		opacity: 1;
		background: var(--brand-softer);
		border-color: var(--brand-soft);
	}

	.ach-emoji {
		font-size: 24px;
		filter: grayscale(1);
	}

	.ach.unlocked .ach-emoji {
		filter: none;
	}

	.ach-name {
		font-size: 10px;
		font-weight: 650;
		color: var(--ink-secondary);
		text-align: center;
	}

	.ach-progress {
		font-size: 10px;
		color: var(--faint);
	}

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
	}

	.s-time {
		color: var(--muted);
	}

	.s-journal {
		color: var(--faint);
		font-size: var(--text-xs);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		flex: 1;
		text-align: end;
	}
</style>
