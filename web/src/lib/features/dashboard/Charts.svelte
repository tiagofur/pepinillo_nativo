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

	const SPARK_W = 280;
	const SPARK_H = 48;
	let sparkPath = $derived.by(() => {
		const values = stats.weekly.map((d) => d.totalFocusSeconds);
		const max = Math.max(1, ...values);
		const step = SPARK_W / Math.max(1, values.length - 1);
		const points = values.map((v, i) => `${(i * step).toFixed(1)},${(SPARK_H - (v / max) * (SPARK_H - 6)).toFixed(1)}`);
		return `M${points.join(' L')}`;
	});
	let sparkArea = $derived(`${sparkPath} L${SPARK_W},${SPARK_H} L0,${SPARK_H} Z`);

	let weekMax = $derived(Math.max(1, ...stats.weekly.map((d) => d.totalFocusSeconds)));
	let modeTotal = $derived(Math.max(1, stats.modeBreakdown.reduce((acc, m) => acc + m.seconds, 0)));

	function fmtMin(seconds: number): string {
		const m = Math.round(seconds / 60);
		if (m < 60) return `${m}m`;
		return `${Math.floor(m / 60)}h ${m % 60}m`;
	}
</script>

<div class="charts">
	<div class="card chart-card">
		<h3>{periodDays === 7 ? t('chart.week') : t('chart.window', { days: periodDays })}</h3>
		<svg class="spark" viewBox="0 0 {SPARK_W} {SPARK_H}" preserveAspectRatio="none" aria-hidden="true">
			<path class="spark-area" d={sparkArea} />
			<path class="spark-line" d={sparkPath} />
		</svg>
		<div class="week-days" class:compact={!showDayBars}>
			{#each stats.weekly as d, i (d.date)}
				<div class="week-col">
					<span class="nums week-val">{d.totalFocusSeconds > 0 ? fmtMin(d.totalFocusSeconds) : ''}</span>
					<div class="week-bar" style="height: {(d.totalFocusSeconds / weekMax) * 100}%; background: {d.totalFocusSeconds > 0 ? 'var(--brand)' : 'var(--surface-sunken)'}"></div>
					<span class="week-label">{showDayBars ? t(WEEKDAY_KEYS[new Date(`${d.date}T12:00:00`).getDay()]) : ''}</span>
				</div>
			{/each}
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

	.spark {
		width: 100%;
		height: 48px;
	}

	.spark-line {
		fill: none;
		stroke: var(--brand);
		stroke-width: 2;
		stroke-linecap: round;
	}

	.spark-area {
		fill: var(--brand-softer);
	}

	.week-days {
		display: flex;
		align-items: flex-end;
		gap: var(--space-2);
	}

	.week-col {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
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
