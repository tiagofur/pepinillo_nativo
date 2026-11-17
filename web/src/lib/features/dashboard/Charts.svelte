<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import type { FocusMode } from '$lib/domain/entities/types';
	import type { DashboardStats } from '$lib/domain/dashboard/stats';

	let { stats, periodDays = 7 }: { stats: DashboardStats; periodDays?: number } = $props();

	let showDayBars = $derived(periodDays <= 31);

	const MODE_COLORS: Record<FocusMode, string> = {
		pomodoro: 'var(--mode-pomodoro)',
		flowtime: 'var(--mode-flowtime)',
		timeblock: 'var(--mode-timeblock)',
		stopwatch: 'var(--mode-stopwatch)'
	};

	const MODE_KEYS: Record<FocusMode, MessageKey> = {
		pomodoro: 'focus.mode.pomodoro',
		flowtime: 'focus.mode.flowtime',
		timeblock: 'focus.mode.timeblock',
		stopwatch: 'focus.mode.stopwatch'
	};

	const WEEKDAY_KEYS: MessageKey[] = [
		'chart.day.sun',
		'chart.day.mon',
		'chart.day.tue',
		'chart.day.wed',
		'chart.day.thu',
		'chart.day.fri',
		'chart.day.sat'
	];

	let weekMax = $derived(Math.max(1, ...stats.weekly.map((d) => d.totalFocusSeconds)));
	let modeTotal = $derived(Math.max(1, stats.modeBreakdown.reduce((acc, m) => acc + m.seconds, 0)));
	let weekTotal = $derived(stats.weekly.reduce((acc, d) => acc + d.totalFocusSeconds, 0));
	// Mac weekly chart: today's bar full pomodoro color, past days at 0.35.
	let todayKey = $derived(stats.weekly.at(-1)?.date ?? '');
	let bestDayLabel = $derived.by(() => {
		const best = stats.weekly.reduce(
			(best, d, i) => (d.totalFocusSeconds > stats.weekly[best].totalFocusSeconds ? i : best),
			0
		);
		const d = stats.weekly[best];
		return d && d.totalFocusSeconds > 0 ? t(WEEKDAY_KEYS[new Date(`${d.date}T12:00:00`).getDay()]) : '—';
	});


	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}
</script>

<div class="charts">
	<div class="card chart-card">
		<h3>{periodDays === 7 ? t('chart.week') : t('chart.window', { days: periodDays })}</h3>
		<div class="week-days" class:compact={!showDayBars}>
			{#each stats.weekly as d, i (d.date)}
				<div class="week-col">
					<span class="nums week-val">{showDayBars && d.totalFocusSeconds > 0 ? fmtMin(d.totalFocusSeconds) : ''}</span>
					<div
						class="week-bar"
						style="height: {(d.totalFocusSeconds / weekMax) * 100}%; background: {d.totalFocusSeconds > 0
							? d.date === todayKey
								? 'var(--mode-pomodoro)'
								: 'color-mix(in srgb, var(--mode-pomodoro) 35%, transparent)'
							: 'var(--surface-sunken)'}"
					></div>
					<span class="week-label">{showDayBars ? t(WEEKDAY_KEYS[new Date(`${d.date}T12:00:00`).getDay()]) : ''}</span>
				</div>
			{/each}
		</div>
		<div class="chart-summary">
			<span class="cs-total"><span class="nums">{fmtMin(weekTotal)}</span> {periodDays === 7 ? t('chart.week') : t('chart.window', { days: periodDays })}</span>
			<span class="cs-best">{t('dash.bestDay')}: <span class="nums">{bestDayLabel}</span></span>
		</div>
	</div>

	{#if stats.modeBreakdown.length > 0}
		<div class="card chart-card">
			<h3>{t('chart.modes')}</h3>
			{#each stats.modeBreakdown as m (m.mode)}
				<div class="mode-row">
					<span class="mode-name">{t(MODE_KEYS[m.mode])}</span>
					<div class="mode-bar-bg">
						<div class="mode-bar" style="width: {(m.seconds / modeTotal) * 100}%; background: {MODE_COLORS[m.mode]}"></div>
					</div>
					<span class="nums mode-val">{fmtMin(m.seconds)}</span>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.charts {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
		gap: var(--space-4);
	}

	.chart-card {
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

	/* Mac weekly chart: bars minHeight 220 area, corner radius 4 */
	.week-days {
		display: flex;
		align-items: stretch;
		gap: var(--space-2);
		height: 148px;
	}

	.week-col {
		flex: 1;
		display: flex;
		flex-direction: column;
		justify-content: flex-end;
		align-items: center;
		gap: var(--space-1);
		height: 100%;
	}

	.week-val {
		font-size: 10px;
		color: var(--muted);
		min-height: 14px;
	}

	.week-bar {
		width: 100%;
		min-height: 4px;
		border-radius: 4px 4px 0 0;
		transition: height var(--dur-slow) var(--ease-out-quint);
	}

	.week-label {
		font-size: 10px;
		color: var(--faint);
		font-weight: 600;
		min-height: 14px;
	}

	.chart-summary {
		display: flex;
		align-items: baseline;
		justify-content: space-between;
		gap: var(--space-3);
		padding-top: var(--space-3);
		border-top: 1px solid var(--hairline);
		font-size: var(--text-sm);
		color: var(--muted);
	}

	.cs-total .nums {
		color: var(--ink);
		font-weight: 650;
	}

	.week-days.compact .week-bar {
		border-radius: 1px;
	}

	.week-days.compact .week-val {
		display: none;
	}

	.mode-row {
		display: flex;
		align-items: center;
		gap: var(--space-3);
	}

	.mode-name {
		width: 76px;
		flex: none;
		font-size: var(--text-sm);
		color: var(--ink-secondary);
		font-weight: 550;
	}

	.mode-bar-bg {
		flex: 1;
		height: 10px;
		border-radius: var(--radius-pill);
		background: var(--surface-sunken);
		overflow: hidden;
	}

	.mode-bar {
		height: 100%;
		border-radius: var(--radius-pill);
		transition: width var(--dur-slow) var(--ease-out-quint);
	}

	.mode-val {
		width: 56px;
		text-align: end;
		font-size: var(--text-sm);
		color: var(--muted);
	}
</style>
