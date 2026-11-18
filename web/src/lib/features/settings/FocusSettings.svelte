<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { playCompletionSound, primeAudio } from '$lib/domain/audio/sounds';
	import Switch from '$lib/design/Switch.svelte';
	import type { CompletionSoundName } from '$lib/domain/entities/types';
	import { msUntilNextFire } from '$lib/domain/notifications/reminder';

	const SOUNDS: { id: CompletionSoundName; key: MessageKey }[] = [
		{ id: 'classic', key: 'sound.classic' },
		{ id: 'chime', key: 'sound.chime' },
		{ id: 'bell', key: 'sound.bell' },
		{ id: 'digital', key: 'sound.digital' },
		{ id: 'woodblock', key: 'sound.woodblock' }
	];

	function pickSound(id: CompletionSoundName): void {
		app.updatePrefs({ completionSound: id });
		primeAudio();
		if (app.prefs.soundEnabled) playCompletionSound(id, 1);
	}

	const SECTIONS: { id: 'focus' | 'plan' | 'dashboard'; key: MessageKey }[] = [
		{ id: 'focus', key: 'nav.focus' },
		{ id: 'plan', key: 'nav.plan' },
		{ id: 'dashboard', key: 'nav.dashboard' }
	];

	function nextFireLabel(): string {
		const ms = msUntilNextFire(app.prefs.dailyReminderHour, app.prefs.dailyReminderMinute);
		const h = Math.floor(ms / 3600000);
		const m = Math.round((ms % 3600000) / 60000);
		return h > 0 ? `${h}h ${m}m` : `${m}m`;
	}

	function toggleNotifications(): void {
		if (!app.prefs.notificationsEnabled) {
			void focus.requestNotifications().then((granted) => {
				app.updatePrefs({ notificationsEnabled: granted });
			});
		} else {
			app.updatePrefs({ notificationsEnabled: false });
		}
	}
</script>

<div class="card section">
	<h2>🍅 {t('settings.focus.title')}</h2>

	<div class="grid">
		<label class="num">
			<span>{t('settings.pomodoro.work')}</span>
			<input
				type="number"
				min="5"
				max="120"
				value={app.prefs.pomodoroWorkMinutes}
				onchange={(e) => app.updatePrefs({ pomodoroWorkMinutes: Number(e.currentTarget.value) })}
			/>
		</label>
		<label class="num">
			<span>{t('settings.pomodoro.break')}</span>
			<input
				type="number"
				min="1"
				max="30"
				value={app.prefs.pomodoroBreakMinutes}
				onchange={(e) => app.updatePrefs({ pomodoroBreakMinutes: Number(e.currentTarget.value) })}
			/>
		</label>
		<label class="num">
			<span>{t('settings.pomodoro.longBreak')}</span>
			<input
				type="number"
				min="5"
				max="60"
				value={app.prefs.pomodoroLongBreakMinutes}
				onchange={(e) => app.updatePrefs({ pomodoroLongBreakMinutes: Number(e.currentTarget.value) })}
			/>
		</label>
		<label class="num">
			<span>{t('settings.pomodoro.sessions')}</span>
			<input
				type="number"
				min="2"
				max="8"
				value={app.prefs.pomodoroSessionsBeforeLongBreak}
				onchange={(e) =>
					app.updatePrefs({ pomodoroSessionsBeforeLongBreak: Number(e.currentTarget.value) })}
			/>
		</label>
		<label class="num">
			<span>{t('settings.flowtime.min')}</span>
			<input
				type="number"
				min="1"
				max="60"
				value={app.prefs.flowtimeMinSessionMinutes}
				onchange={(e) => app.updatePrefs({ flowtimeMinSessionMinutes: Number(e.currentTarget.value) })}
			/>
		</label>
		<label class="num">
			<span>{t('settings.timeblock.minutes')}</span>
			<input
				type="number"
				min="5"
				max="180"
				value={app.prefs.timeBlockMinutes}
				onchange={(e) => app.updatePrefs({ timeBlockMinutes: Number(e.currentTarget.value) })}
			/>
		</label>
	</div>

	<div class="toggles">
		<div class="switch-row">
			<span>{t('settings.autoStartBreaks')}</span>
			<Switch checked={app.prefs.autoStartBreaks} onchange={(v) => app.updatePrefs({ autoStartBreaks: v })} label={t('settings.autoStartBreaks')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.autoStartWork')}</span>
			<Switch checked={app.prefs.autoStartWork} onchange={(v) => app.updatePrefs({ autoStartWork: v })} label={t('settings.autoStartWork')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.timeblock.midpoint')}</span>
			<Switch checked={app.prefs.timeBlockMidpointCheckIn} onchange={(v) => app.updatePrefs({ timeBlockMidpointCheckIn: v })} label={t('settings.timeblock.midpoint')} />
		</div>
	</div>
</div>

<div class="card section">
	<h2>🔔 {t('settings.sound.title')}</h2>
	<div class="switch-row">
			<span>{t('settings.sound.enabled')}</span>
			<Switch checked={app.prefs.soundEnabled} onchange={(v) => app.updatePrefs({ soundEnabled: v })} label={t('settings.sound.enabled')} />
		</div>
	<div class="row wrap">
		{#each SOUNDS as s (s.id)}
			<button
				class="chip pressable"
				aria-pressed={app.prefs.completionSound === s.id}
				class:is-active={app.prefs.completionSound === s.id}
				onclick={() => pickSound(s.id)}
			>
				{t(s.key)}
			</button>
		{/each}
	</div>
</div>

<div class="card section">
	<h2>⚙️ {t('settings.behavior.title')}</h2>
	<div class="toggles">
		<div class="switch-row">
			<span>{t('settings.haptics')}</span>
			<Switch checked={app.prefs.hapticsEnabled} onchange={(v) => app.updatePrefs({ hapticsEnabled: v })} label={t('settings.haptics')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.keepScreenOn')}</span>
			<Switch checked={app.prefs.keepScreenOn} onchange={(v) => app.updatePrefs({ keepScreenOn: v })} label={t('settings.keepScreenOn')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.journal')}</span>
			<Switch checked={app.prefs.showJournalAfterSession} onchange={(v) => app.updatePrefs({ showJournalAfterSession: v })} label={t('settings.journal')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.adhd')}</span>
			<Switch checked={app.prefs.adhdFriendlyEnabled} onchange={(v) => app.updatePrefs({ adhdFriendlyEnabled: v })} label={t('settings.adhd')} />
		</div>
		<div class="switch-row">
			<span>{t('settings.notifications')}</span>
			<Switch checked={app.prefs.notificationsEnabled} onchange={() => toggleNotifications()} label={t('settings.notifications')} />
		</div>
	</div>
	<p class="hint">{t('settings.notifications.hint')}</p>

	<div class="toggles">
		<div class="switch-row">
			<span>{t('settings.dailyReminder')}</span>
			<Switch checked={app.prefs.dailyReminderEnabled} onchange={(v) => app.updatePrefs({ dailyReminderEnabled: v })} label={t('settings.dailyReminder')} />
		</div>
		{#if app.prefs.dailyReminderEnabled}
			<div class="reminder-time">
				<input
					type="number"
					min="0"
					max="23"
					value={app.prefs.dailyReminderHour}
					onchange={(e) => app.updatePrefs({ dailyReminderHour: Number(e.currentTarget.value) })}
					aria-label={t('settings.reminderHour')}
				/>
				<span class="muted">:</span>
				<input
					type="number"
					min="0"
					max="59"
					value={app.prefs.dailyReminderMinute}
					onchange={(e) => app.updatePrefs({ dailyReminderMinute: Number(e.currentTarget.value) })}
					aria-label={t('settings.reminderMinute')}
				/>
				<span class="muted nums">→ {t('settings.reminderNext', { time: nextFireLabel() })}</span>
			</div>
		{/if}
		<div class="switch-row">
			<span>{t('settings.weeklyRecap')}</span>
			<Switch checked={app.prefs.weeklyRecapEnabled} onchange={(v) => app.updatePrefs({ weeklyRecapEnabled: v })} label={t('settings.weeklyRecap')} />
		</div>
	</div>
</div>

<div class="card section">
	<h2>🏆 {t('settings.streak.title')}</h2>
	<div class="toggles">
		<div class="switch-row">
			<span>{t('settings.celebrateRecords')}</span>
			<Switch checked={app.prefs.celebrateRecordsEnabled} onchange={(v) => app.updatePrefs({ celebrateRecordsEnabled: v })} label={t('settings.celebrateRecords')} />
		</div>
	</div>
</div>

<div class="card section">
	<h2>🔒 {t('settings.privacy.title')}</h2>
	<div class="toggles">
		<div class="switch-row">
			<span>{t('settings.analytics')}</span>
			<Switch checked={app.prefs.analyticsOptIn} onchange={(v) => app.updatePrefs({ analyticsOptIn: v })} label={t('settings.analytics')} />
		</div>
	</div>
	<p class="hint">{t('settings.analytics.hint')}</p>
</div>

<div class="card section">
	<h2>🚀 {t('settings.startup.title')}</h2>
	<div class="row wrap">
		{#each SECTIONS as s2 (s2.id)}
			<button
				class="chip pressable"
				aria-pressed={app.prefs.defaultSection === s2.id}
				class:is-active={app.prefs.defaultSection === s2.id}
				onclick={() => app.updatePrefs({ defaultSection: s2.id })}
			>
				{t(s2.key)}
			</button>
		{/each}
	</div>
	<p class="hint">{t('settings.startup.hint')}</p>
</div>

<style>
	.section {
		padding: var(--space-5);
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	h2 {
		font-size: var(--text-base);
		font-weight: 650;
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
		gap: var(--space-3);
	}

	label {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		font-size: var(--text-sm);
		color: var(--muted);
		font-weight: 550;
	}

	input[type='number'] {
		width: 100%;
	}

	.toggles {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.switch-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-4);
		min-height: 44px;
		color: var(--ink-secondary);
	}

	.switch-row > span:first-child {
		font-size: var(--text-sm);
	}


	.row {
		display: flex;
		gap: var(--space-2);
	}

	.wrap {
		flex-wrap: wrap;
	}

	.hint {
		color: var(--faint);
		font-size: var(--text-xs);
	}
</style>
