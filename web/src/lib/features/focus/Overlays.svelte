<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import { STREAK_THRESHOLDS } from '$lib/domain/celebrations/milestones';

	const MILESTONE_EMOJI: Record<string, string> = {
		firstSession: '🎯',
		streak: '⚡',
		sessionCount: '✨',
		personalBest: '🚀'
	};

	let emoji = $derived.by(() => {
		const m = focus.milestone;
		if (!m) return '';
		if (m.kind === 'streak') return m.days >= 14 ? '🏆' : '⚡';
		if (m.kind === 'sessionCount') return m.count >= 50 ? '💎' : '✨';
		return MILESTONE_EMOJI[m.kind] ?? '✨';
	});

	let milestoneTitle = $derived.by(() => {
		const m = focus.milestone;
		if (!m) return '';
		if (m.kind === 'firstSession') return t('celebration.firstSession.title');
		if (m.kind === 'streak') return t('celebration.streak.title', { days: m.days });
		if (m.kind === 'sessionCount') return t('celebration.sessionCount.title', { count: m.count });
		return t('celebration.personalBest.title', { minutes: m.minutes });
	});

	let milestoneBody = $derived.by(() => {
		const m = focus.milestone;
		if (!m) return '';
		if (m.kind === 'firstSession') return t('celebration.firstSession.body');
		if (m.kind === 'streak') return t('celebration.streak.body');
		if (m.kind === 'sessionCount') return t('celebration.sessionCount.body');
		return t('celebration.personalBest.body');
	});
</script>

<!-- Milestone celebration overlay: the ONE bouncy moment -->
{#if focus.milestone}
	<div class="celebrate-backdrop" role="alert">
		<div class="celebrate">
			<span class="emoji pop">{emoji}</span>
			<h2 class="pop">{milestoneTitle}</h2>
			<p>{milestoneBody}</p>
			<button class="btn btn-soft pressable" onclick={() => focus.dismissMilestone()}>
				{t('celebration.keepGoing')}
			</button>
		</div>
	</div>
{/if}

<!-- Personal streak record banner (compact, like the native StreakRecordBanner) -->
{#if focus.streakRecord && !focus.milestone}
	<button
		class="record-banner pressable"
		onclick={() => focus.dismissStreakRecord()}
		aria-label={t('celebration.record.dismiss')}
	>
		🔥 <span>{t('celebration.record.title', { days: focus.streak })}</span>
	</button>
{/if}

<!-- Ghost resume dialog -->
{#if focus.ghost}
	<div class="ghost card">
		<h3>🕯️ {t('focus.ghost.title')}</h3>
		<p class="ghost-body">
			{t('focus.ghost.body', { time: focus.displayTime, mode: t(`focus.mode.${focus.ghost.mode}`) })}
		</p>
		<div class="ghost-actions">
			<button class="btn btn-primary pressable" onclick={() => focus.resumeGhost()}>
				{t('focus.ghost.resume')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => focus.discardGhost()}>
				{t('focus.ghost.discard')}
			</button>
		</div>
	</div>
{/if}

<style>
	.celebrate-backdrop {
		position: fixed;
		inset: 0;
		z-index: 80;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(0, 0, 0, 0.55);
		padding: var(--space-6);
		cursor: pointer;
	}

	.celebrate {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-3);
		text-align: center;
		color: #fff;
		max-width: 420px;
	}

	.emoji {
		font-size: 64px;
		line-height: 1;
	}

	.pop {
		animation: pop-celebrate var(--dur-celebrate) var(--spring) both;
	}

	h2 {
		font-size: var(--text-xl);
	}

	p {
		color: rgba(255, 255, 255, 0.85);
	}

	.celebrate .btn {
		margin-top: var(--space-4);
	}

	.record-banner {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: var(--touch-target);
		padding: 0 var(--space-5);
		border: 1px solid var(--border);
		border-radius: var(--radius-pill);
		background: var(--streak-soft);
		color: var(--streak);
		font-weight: 650;
		cursor: pointer;
		animation: rise-in var(--dur-slow) var(--ease-out-quint) both;
	}

	.ghost {
		width: min(480px, 100%);
		margin: 0 auto var(--space-6);
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.ghost-body {
		color: var(--muted);
	}

	.ghost-actions {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
	}

	@media (prefers-reduced-motion: reduce) {
		.pop,
		.record-banner {
			animation: none;
		}
	}
</style>
