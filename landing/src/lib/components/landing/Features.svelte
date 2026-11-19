<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';

	const FEATURES: { title: MessageKey; body: MessageKey; color: string; emoji: string }[] = [
		{ title: 'landing.feat.modes.title', body: 'landing.feat.modes.body', color: 'var(--mode-pomodoro)', emoji: '🍅' },
		{ title: 'landing.feat.tasks.title', body: 'landing.feat.tasks.body', color: 'var(--mode-flowtime)', emoji: '🗂️' },
		{ title: 'landing.feat.stats.title', body: 'landing.feat.stats.body', color: 'var(--streak)', emoji: '📈' },
		{ title: 'landing.feat.sync.title', body: 'landing.feat.sync.body', color: 'var(--mode-timeblock)', emoji: '☁️' }
	];
</script>

<section class="features">
	{#each FEATURES as f, i (f.title)}
		<article class="feat" class:flip={i % 2 === 1}>
			<div class="feat-emoji" style="background: color-mix(in srgb, {f.color} 12%, transparent)">
				{f.emoji}
			</div>
			<div class="feat-copy">
				<h2>{t(f.title)}</h2>
				<p>{t(f.body)}</p>
			</div>
		</article>
	{/each}
</section>

<style>
	.features {
		display: flex;
		flex-direction: column;
		gap: var(--space-10);
	}

	.feat {
		display: flex;
		align-items: center;
		gap: var(--space-6);
		max-width: 720px;
	}

	.feat.flip {
		margin-inline-start: auto;
		flex-direction: row-reverse;
		text-align: end;
	}

	.feat-emoji {
		flex: none;
		width: 72px;
		height: 72px;
		border-radius: var(--radius-lg);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 32px;
	}

	.feat h2 {
		font-size: var(--text-lg);
		margin-bottom: var(--space-2);
	}

	.feat p {
		color: var(--muted);
		max-width: 46ch;
	}

	.feat.flip p {
		margin-inline-start: auto;
	}

	@media (max-width: 599px) {
		.feat,
		.feat.flip {
			flex-direction: column;
			text-align: start;
			gap: var(--space-3);
		}

		.feat.flip p {
			margin-inline-start: 0;
		}
	}
</style>
