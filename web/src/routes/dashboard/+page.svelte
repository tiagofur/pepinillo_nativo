<script lang="ts">
	import { goto } from '$app/navigation';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/messages';
	import { formatMs } from '$lib/format/time';
	import { summarizeSessions } from '$lib/domain/dashboard/summary';
	import type { FocusMode } from '$lib/domain/entities/types';
	import EmptyIllustration from '$lib/components/EmptyIllustration.svelte';

	const locale = $derived(app.locale);
	const summary = $derived(summarizeSessions(app.sessions, new Date()));

	const recent = $derived(
		[...app.sessions]
			.filter((s) => s.status === 'completed' || s.status === 'skipped')
			.sort((a, b) => (b.completedAt ?? b.updatedAt).localeCompare(a.completedAt ?? a.updatedAt))
			.slice(0, 5)
	);

	const avgMinutes = $derived.by(() => {
		const n = summary.last7Days.sessionCount;
		if (n === 0) return 0;
		return Math.round(summary.last7Days.focusMinutes / n);
	});

	function modeLabel(mode: FocusMode): string {
		switch (mode) {
			case 'pomodoro':
				return t(locale, 'focus.mode.pomodoro');
			case 'stopwatch':
				return t(locale, 'focus.mode.stopwatch');
			case 'flowtime':
				return t(locale, 'focus.mode.flowtime');
			case 'timeblock':
				return t(locale, 'focus.mode.timeblock');
		}
	}

	function modeColor(mode: FocusMode): string {
		switch (mode) {
			case 'stopwatch':
				return 'var(--mode-stopwatch)';
			case 'flowtime':
				return 'var(--mode-flowtime)';
			case 'timeblock':
				return 'var(--mode-timeblock)';
			default:
				return 'var(--mode-pomodoro)';
		}
	}
</script>

<section class="panel dash-screen">
	<div class="panel-head">
		<div>
			<h1>{t(locale, 'dashboard.title')}</h1>
			<p class="muted panel-sub">{t(locale, 'dashboard.subtitle')}</p>
		</div>
	</div>

	<div class="dash-hero card">
		<div class="dash-hero-main">
			<span class="dash-hero-kicker">{t(locale, 'dashboard.today')}</span>
			<strong class="dash-hero-value">{summary.today.focusMinutes}</strong>
			<span class="muted">{t(locale, 'dashboard.minutes')}</span>
			<span class="muted"
				>{summary.today.sessionCount} {t(locale, 'dashboard.sessions')}</span
			>
		</div>
		<button class="btn btn-primary" type="button" onclick={() => goto('/focus/')}>
			{t(locale, 'dashboard.heroCta')}
		</button>
	</div>

	{#if app.sessions.length === 0}
		<div class="empty-state">
			<EmptyIllustration kind="dashboard" />
			<p class="muted" style="margin: 0 0 var(--space-3);">{t(locale, 'dashboard.empty')}</p>
			<button class="btn btn-primary" type="button" onclick={() => goto('/focus/')}>
				{t(locale, 'dashboard.heroCta')}
			</button>
		</div>
	{/if}

	<div class="stat-grid">
		<div class="stat">
			<span class="stat-label">{t(locale, 'dashboard.last7')}</span>
			<strong>{summary.last7Days.focusMinutes}</strong>
			<span class="muted">{t(locale, 'dashboard.minutes')}</span>
			<span class="muted"
				>{summary.last7Days.sessionCount} {t(locale, 'dashboard.sessions')}</span
			>
		</div>
		<div class="stat">
			<span class="stat-label">{t(locale, 'dashboard.avgSession')}</span>
			<strong>{avgMinutes}</strong>
			<span class="muted">{t(locale, 'dashboard.minutes')}</span>
		</div>
	</div>

	{#if recent.length > 0}
		<div class="recent-block">
			<h2 class="section-title">{t(locale, 'dashboard.recent')}</h2>
			<ul class="recent-list">
				{#each recent as session (session.id)}
					<li class="recent-item">
						<span class="recent-dot" style="background: {modeColor(session.mode)}"></span>
						<div class="recent-body">
							<strong>{modeLabel(session.mode)}</strong>
							<span class="muted"
								>{formatMs(session.elapsedMs)}
								{#if session.completedAt}
									· {new Date(session.completedAt).toLocaleDateString(locale)}
								{/if}
							</span>
						</div>
					</li>
				{/each}
			</ul>
		</div>
	{/if}

	<p class="teaser">{t(locale, 'dashboard.extendedGated')}</p>
</section>
