<script lang="ts">
	/** Post-session journal sheet. The Link Task / Soundscape chips and
	 * their sheets live in FocusChips.svelte (Mac stage position). */
	import Sheet from '$lib/design/Sheet.svelte';
	import { focus } from '$lib/stores/focus.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	const RATINGS: { value: 1 | 2 | 3 | 4 | 5; key: MessageKey }[] = [
		{ value: 1, key: 'journal.rating.1' },
		{ value: 2, key: 'journal.rating.2' },
		{ value: 3, key: 'journal.rating.3' },
		{ value: 4, key: 'journal.rating.4' },
		{ value: 5, key: 'journal.rating.5' }
	];

	let rating = $state<0 | 1 | 2 | 3 | 4 | 5>(0);
	let note = $state('');

	function submitJournal(): void {
		if (rating === 0) return;
		focus.saveJournal(rating, note);
		rating = 0;
		note = '';
	}
</script>

<!-- Journal sheet -->
<Sheet open={focus.journalPrompt !== null} onclose={() => focus.dismissJournal()} title={t('journal.title')}>
	<div class="journal">
		<p class="muted">{t('journal.subtitle')}</p>
		<div class="ratings">
			{#each RATINGS as r (r.value)}
				<button
					class="rating pressable"
					class:is-active={rating === r.value}
					aria-pressed={rating === r.value}
					onclick={() => (rating = r.value)}
					title={t(r.key)}
				>
					<span class="face">{['😞', '😐', '🙂', '😊', '🔥'][r.value - 1]}</span>
					<span class="label">{t(r.key)}</span>
				</button>
			{/each}
		</div>
		<textarea
			class="field journal-note"
			rows="3"
			placeholder={t('journal.placeholder')}
			bind:value={note}
		></textarea>
		<div class="row-actions">
			<button class="btn btn-primary pressable" disabled={rating === 0} onclick={submitJournal}>
				{t('journal.save')}
			</button>
			<button class="btn btn-ghost pressable" onclick={() => focus.dismissJournal()}>
				{t('journal.skip')}
			</button>
		</div>
	</div>
</Sheet>

<style>
	.journal {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.muted {
		color: var(--muted);
	}

	.ratings {
		display: flex;
		gap: var(--space-2);
		justify-content: space-between;
	}

	.rating {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-1);
		min-height: 72px;
		padding: var(--space-2);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--surface);
		cursor: pointer;
	}

	.rating.is-active {
		background: var(--brand-soft);
		border-color: var(--brand);
	}

	.face {
		font-size: 26px;
	}

	.label {
		font-size: var(--text-2xs);
		color: var(--muted);
	}

	.journal-note {
		resize: vertical;
	}

	.row-actions {
		display: flex;
		gap: var(--space-3);
	}
</style>
