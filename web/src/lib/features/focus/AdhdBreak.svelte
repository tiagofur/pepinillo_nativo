<script lang="ts">
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';

	/**
	 * Guided break for ADHD-friendly mode (mirror of ADHDBreakView):
	 * cycles gentle activities for the duration of the break phase.
	 */
	const ACTIVITIES = [
		{ key: 'breathe', emoji: '🌬️' },
		{ key: 'stretch', emoji: '🤸' },
		{ key: 'hydrate', emoji: '💧' },
		{ key: 'move', emoji: '🚶' }
	] as const;

	let elapsed = $derived.by(() => {
		const s = focus.session;
		if (!s) return 0;
		return focus.running || focus.paused
			? s.elapsedMs + (s.segmentStartedAt && s.status === 'running'
					? Date.now() - new Date(s.segmentStartedAt).getTime()
					: 0)
			: 0;
	});

	// Change activity every 20 seconds of break.
	let activityIndex = $derived(Math.floor(elapsed / 20_000) % ACTIVITIES.length);
	let activity = $derived(ACTIVITIES[activityIndex]);
</script>

{#if focus.mode !== 'stopwatch' && (focus.phase === 'shortBreak' || focus.phase === 'longBreak') && !focus.idle}
	{#key activityIndex}
		<div class="adhd card">
			<span class="emoji">{activity.emoji}</span>
			<span class="activity">{t(`adhd.${activity.key}`)}</span>
			<span class="muted">{t('adhd.subtitle')}</span>
		</div>
	{/key}
{/if}

<style>
	.adhd {
		width: min(420px, 100%);
		padding: var(--space-4) var(--space-5);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		text-align: center;
	}

	.emoji {
		font-size: 34px;
		animation: rise-in var(--dur-slow) var(--ease-out-quint) both;
	}

	.activity {
		font-weight: 650;
	}

	.muted {
		color: var(--muted);
		font-size: var(--text-xs);
	}
</style>
