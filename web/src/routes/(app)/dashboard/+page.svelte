<script lang="ts">
	import { onMount } from 'svelte';
	import { dashboard } from '$lib/stores/dashboard.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Charts from '$lib/features/dashboard/Charts.svelte';
	import Segmented from '$lib/design/Segmented.svelte';
	import Panels from '$lib/features/dashboard/Panels.svelte';
	import AiCard from '$lib/features/dashboard/AiCard.svelte';
	import ReviewSheet from '$lib/features/dashboard/ReviewSheet.svelte';
	import PaneToolbar from '$lib/features/shell/PaneToolbar.svelte';
	import Icon from '$lib/design/Icon.svelte';
	import { currentLocale } from '$lib/i18n/i18n.svelte';
	import type { AnalyticsPeriod } from '$lib/domain/dashboard/stats';

	onMount(() => {
		void dashboard.init();
	});

	const PERIODS: { days: AnalyticsPeriod; key: MessageKey }[] = [
		{ days: 7, key: 'period.7' },
		{ days: 30, key: 'period.30' },
		{ days: 365, key: 'period.365' }
	];

	const QUALIFIER_KEYS: Record<string, MessageKey> = {
		exceptional: 'score.exceptional',
		strong: 'score.strong',
		steady: 'score.steady',
		warming: 'score.warming',
		rest: 'score.rest'
	};

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}

	function hourLabel(h: number | null): string {
		if (h === null) return '—';
		return `${String(h).padStart(2, '0')}:00`;
	}

	// Mac Today header: localized long date.
	let dateLabel = $derived(
		new Intl.DateTimeFormat(currentLocale(), {
			weekday: 'long',
			day: 'numeric',
			month: 'long',
			year: 'numeric'
		}).format(new Date())
	);
</script>

<svelte:head>
	<title>{t('dashboard.title')} · Pepinillo</title>
</svelte:head>

<section class="dash rise-in">
	<!-- Mac window toolbar: refresh on the right (Today toolbar parity) -->
	<PaneToolbar title={t('dashboard.title')}>
		{#snippet right()}
			<button
				class="pt-btn pressable"
				title={t('dashboard.refresh')}
				aria-label={t('dashboard.refresh')}
				onclick={() => void dashboard.reload()}
			>
				<Icon name="refresh" size={16} />
			</button>
		{/snippet}
	</PaneToolbar>

	{#if dashboard.stats}
		<!-- Mac Today header: long date + subtitle, streak/focus on the right -->
		<header class="date-head">
			<div class="date-block">
				<h2 class="date-title">{dateLabel}</h2>
				<p class="date-sub">{t('dashboard.subtitle')}</p>
			</div>
			<div class="date-side nums">
				<span class="side-chip">🔥 {dashboard.stats.streak > 0 ? dashboard.stats.streak : '—'} · {t('companion.streak')}</span>
				<span class="side-sep" aria-hidden="true"></span>
				<span class="side-chip">{fmtMin(dashboard.stats.todayFocusSeconds)} · {t('companion.focusToday')}</span>
			</div>
		</header>

		{#if dashboard.stats && dashboard.stats.todayFocusSeconds === 0 && dashboard.stats.todaySessions === 0}
			<a class="first-run pressable" href="/focus">
				<span class="fr-title">🌱 {t('dashboard.empty')}</span>
				<span class="fr-cta">{t('dashboard.heroCta')} →</span>
			</a>
		{/if}

		<!-- Flat KPI row (Mac Today): caption label + rounded semibold value -->
		<div class="kpis">
			<div class="kpi">
				<span class="k-head">⏱ {t('companion.focusToday')}</span>
				<span class="k-value nums">{fmtMin(dashboard.stats.todayFocusSeconds)}</span>
			</div>
			<div class="kpi">
				<span class="k-head">🌊 {t('companion.sessionsToday')}</span>
				<span class="k-value nums">{dashboard.stats.todaySessions}</span>
			</div>
			<div class="kpi">
				<span class="k-head">🔥 {t('companion.streak')}</span>
				<span class="k-value nums">{dashboard.stats.streak > 0 ? dashboard.stats.streak : '—'}</span>
			</div>
			<div class="kpi">
				<span class="k-head">🏅 {t('dash.periodFocus')}</span>
				<span class="k-value nums">{fmtMin(dashboard.stats.periodFocusSeconds)}</span>
			</div>
		</div>

		<!-- Focus score + patterns: flat secondary row -->
		<div class="meta-row">
			<span class="meta-score nums">{dashboard.stats.focusScore}</span>
			<span class="meta-score-name">{t(QUALIFIER_KEYS[dashboard.stats.focusScoreQualifier])}</span>
			<span class="meta-item"><span class="nums">{hourLabel(dashboard.stats.peakHour)}</span> {t('dash.peakHour')}</span>
			<span class="meta-item"><span class="nums">{Math.round(dashboard.stats.completionRate * 100)}%</span> {t('dash.completion')}</span>
			<span class="meta-item"><span class="nums">{fmtMin(dashboard.stats.longestSessionMs / 1000)}</span> {t('dash.longest')}</span>
			<span class="meta-item"><span class="nums">{dashboard.unlockedCount}/6</span> {t('achievements.title')}</span>
		</div>

		<!-- Period picker (segmented, Mac style) -->
		<div class="period">
			<Segmented
				compact
				options={PERIODS.map((p) => ({
					id: String(p.days),
					label: p.days === 7 ? t(p.key) : `${p.days}D`,
					disabled: dashboard.periodGated(p.days),
					title: dashboard.periodGated(p.days) ? t('common.proLocked') : undefined
				}))}
				value={String(dashboard.period)}
				onchange={(id) => dashboard.setPeriod(Number(id) as AnalyticsPeriod)}
			/>
		</div>

		<Charts stats={dashboard.stats} periodDays={dashboard.period} />

		<AiCard />

		<Panels achievements={dashboard.achievements} sessions={dashboard.sessions} />

		<ReviewSheet />
	{:else}
		<div class="card empty">
			<p>{t('dashboard.empty')}</p>
		</div>
	{/if}
</section>

<style>
	/* Mac Today: content max 980, padding 24, section spacing 24 */
	.dash {
		display: flex;
		flex-direction: column;
		gap: var(--space-6);
		max-width: var(--content-panel-max);
		margin-inline: auto;
		width: 100%;
	}

	/* ---- Header: long date + subtitle | streak/focus ---- */
	.date-head {
		display: flex;
		align-items: flex-end;
		justify-content: space-between;
		gap: var(--space-4);
		flex-wrap: wrap;
	}

	.date-title {
		font-size: var(--text-xl);
		font-weight: 700;
		letter-spacing: var(--tracking-tight);
		margin: 0;
	}

	.date-sub {
		margin: var(--space-1) 0 0;
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.date-side {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		color: var(--ink-secondary);
		font-weight: 600;
		font-size: var(--text-sm);
	}

	.side-sep {
		width: 1px;
		height: 18px;
		background: var(--border);
	}

	.first-run {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-3);
		flex-wrap: wrap;
		padding: var(--space-4) var(--space-5);
		border: 1px solid var(--brand-soft);
		border-radius: var(--radius-lg);
		background: var(--brand-softer);
	}

	.fr-title {
		font-weight: 650;
		color: var(--ink);
	}

	.fr-cta {
		color: var(--brand);
		font-weight: 700;
	}

	.link-btn {
		border: none;
		background: none;
		color: var(--brand);
		font-weight: 600;
		font-size: var(--text-sm);
		cursor: pointer;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-sm);
	}

	.link-btn:hover {
		background: var(--brand-softer);
	}

	.ha-sep {
		color: var(--faint);
	}

	/* ---- Flat KPI row ---- */
	.kpis {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: var(--space-6);
	}

	.kpi {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.k-head {
		font-size: var(--text-xs);
		font-weight: 600;
		color: var(--muted);
	}

	.k-value {
		font-family: var(--font-rounded);
		font-size: var(--text-xl);
		font-weight: 650;
		letter-spacing: var(--tracking-tight);
		color: var(--ink);
		font-variant-numeric: tabular-nums;
	}

	/* ---- Score + patterns: flat secondary row ---- */
	.meta-row {
		display: flex;
		align-items: baseline;
		gap: var(--space-5);
		flex-wrap: wrap;
		padding: var(--space-4) 0;
		border-top: 1px solid var(--hairline);
		border-bottom: 1px solid var(--hairline);
	}

	.meta-score {
		font-family: var(--font-rounded);
		font-size: var(--text-lg);
		font-weight: 650;
		color: var(--brand);
		font-variant-numeric: tabular-nums;
	}

	.meta-score-name {
		color: var(--ink-secondary);
		font-weight: 600;
		font-size: var(--text-sm);
		margin-right: var(--space-4);
	}

	.meta-item {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.meta-item .nums {
		color: var(--ink-secondary);
		font-weight: 650;
	}

	.period :global(.segmented) {
		width: 200px;
	}

	.period :global(.segmented button) {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
	}

	.empty {
		padding: var(--space-10);
		text-align: center;
		color: var(--muted);
	}

	@media (max-width: 767px) {
		.kpis {
			grid-template-columns: repeat(2, 1fr);
			gap: var(--space-4);
		}
	}
</style>
