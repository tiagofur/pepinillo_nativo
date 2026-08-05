<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/messages';
	import { summarizeSessions } from '$lib/domain/dashboard/summary';

	const locale = $derived(app.locale);
	const summary = $derived(summarizeSessions(app.sessions, new Date()));
</script>

<section class="panel">
	<div class="panel-head">
		<h1>{t(locale, 'dashboard.title')}</h1>
	</div>

	{#if app.sessions.length === 0}
		<p class="muted">{t(locale, 'dashboard.empty')}</p>
	{/if}

	<div class="stat-grid">
		<div class="stat">
			<strong>{summary.today.focusMinutes}</strong>
			<span class="muted">{t(locale, 'dashboard.today')} · {t(locale, 'dashboard.minutes')}</span>
			<span class="muted"
				>{summary.today.sessionCount} {t(locale, 'dashboard.sessions')}</span
			>
		</div>
		<div class="stat">
			<strong>{summary.last7Days.focusMinutes}</strong>
			<span class="muted">{t(locale, 'dashboard.last7')} · {t(locale, 'dashboard.minutes')}</span>
			<span class="muted"
				>{summary.last7Days.sessionCount} {t(locale, 'dashboard.sessions')}</span
			>
		</div>
	</div>

	<p class="teaser">{t(locale, 'dashboard.extendedGated')}</p>
</section>
