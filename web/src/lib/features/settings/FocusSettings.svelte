<script lang="ts">
	import { app } from '$lib/stores/app.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { playCompletionSound, primeAudio } from '$lib/domain/audio/sounds';
	import type { CompletionSoundName } from '$lib/domain/entities/types';

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
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.autoStartBreaks}
				onchange={(e) => app.updatePrefs({ autoStartBreaks: e.currentTarget.checked })}
			/>
			<span>{t('settings.autoStartBreaks')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.autoStartWork}
				onchange={(e) => app.updatePrefs({ autoStartWork: e.currentTarget.checked })}
			/>
			<span>{t('settings.autoStartWork')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.timeBlockMidpointCheckIn}
				onchange={(e) => app.updatePrefs({ timeBlockMidpointCheckIn: e.currentTarget.checked })}
			/>
			<span>{t('settings.timeblock.midpoint')}</span>
		</label>
	</div>
</div>

<div class="card section">
	<h2>🔔 {t('settings.sound.title')}</h2>
	<label class="switch">
		<input
			type="checkbox"
			checked={app.prefs.soundEnabled}
			onchange={(e) => app.updatePrefs({ soundEnabled: e.currentTarget.checked })}
		/>
		<span>{t('settings.sound.enabled')}</span>
	</label>
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
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.hapticsEnabled}
				onchange={(e) => app.updatePrefs({ hapticsEnabled: e.currentTarget.checked })}
			/>
			<span>{t('settings.haptics')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.keepScreenOn}
				onchange={(e) => app.updatePrefs({ keepScreenOn: e.currentTarget.checked })}
			/>
			<span>{t('settings.keepScreenOn')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.showJournalAfterSession}
				onchange={(e) => app.updatePrefs({ showJournalAfterSession: e.currentTarget.checked })}
			/>
			<span>{t('settings.journal')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.adhdFriendlyEnabled}
				onchange={(e) => app.updatePrefs({ adhdFriendlyEnabled: e.currentTarget.checked })}
			/>
			<span>{t('settings.adhd')}</span>
		</label>
		<label class="switch">
			<input
				type="checkbox"
				checked={app.prefs.notificationsEnabled}
				onchange={toggleNotifications}
			/>
			<span>{t('settings.notifications')}</span>
		</label>
	</div>
	<p class="hint">{t('settings.notifications.hint')}</p>
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

	.switch {
		flex-direction: row;
		align-items: center;
		gap: var(--space-3);
		color: var(--ink-secondary);
		min-height: var(--touch-target);
		cursor: pointer;
	}

	.switch input {
		width: 20px;
		height: 20px;
		accent-color: var(--brand);
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
