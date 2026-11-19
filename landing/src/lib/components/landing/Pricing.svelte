<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { UPGRADE_URL, WEB_APP_URL } from '$lib/domain/links';

	type Plan = {
		key: 'free' | 'plus' | 'everywhere';
		name: MessageKey;
		price: MessageKey;
		note: MessageKey;
		bullets: MessageKey[];
		cta: MessageKey;
		href: string;
		primary?: boolean;
	};

	const PLANS: Plan[] = [
		{
			key: 'free',
			name: 'upgrade.plan.free',
			price: 'upgrade.price.free',
			note: 'upgrade.note.free',
			bullets: ['upgrade.free.pomodoro', 'upgrade.free.stopwatch', 'upgrade.free.tasks', 'upgrade.free.analytics'],
			cta: 'upgrade.cta.free',
			href: WEB_APP_URL
		},
		{
			key: 'plus',
			name: 'upgrade.plan.plus',
			price: 'upgrade.price.plus',
			note: 'upgrade.note.plus',
			bullets: [
				'upgrade.plus.modes',
				'upgrade.plus.tasks',
				'upgrade.plus.subtasks',
				'upgrade.plus.themes',
				'upgrade.plus.analytics',
				'upgrade.plus.soundscapes'
			],
			cta: 'upgrade.cta.plus',
			href: UPGRADE_URL
		},
		{
			key: 'everywhere',
			name: 'upgrade.plan.everywhere',
			price: 'upgrade.price.everywhere',
			note: 'upgrade.note.everywhere',
			bullets: [
				'upgrade.everywhere.plusIncluded',
				'upgrade.everywhere.sync',
				'upgrade.everywhere.ai',
				'upgrade.everywhere.recovery',
				'upgrade.everywhere.web'
			],
			cta: 'upgrade.cta.everywhere',
			href: UPGRADE_URL,
			primary: true
		}
	];
</script>

<section class="pricing" id="pricing">
	<header class="pricing-head">
		<h2>{t('landing.pricing.title')}</h2>
		<p>{t('landing.pricing.sub')}</p>
	</header>

	<div class="plans">
		{#each PLANS as plan (plan.key)}
			<article class="plan card" class:featured={plan.primary}>
				{#if plan.primary}
					<span class="flag">{t('upgrade.flag.best')}</span>
				{/if}
				<h3>{t(plan.name)}</h3>
				<p class="price">{t(plan.price)}</p>
				<p class="note">{t(plan.note)}</p>
				<ul>
					{#each plan.bullets as b (b)}
						<li>{t(b)}</li>
					{/each}
				</ul>
				<a class="btn pressable {plan.primary ? 'btn-primary' : 'btn-outline'}" href={plan.href}>
					{t(plan.cta)}
				</a>
			</article>
		{/each}
	</div>
</section>

<style>
	.pricing {
		display: flex;
		flex-direction: column;
		gap: var(--space-10);
		scroll-margin-top: 84px;
	}

	.pricing-head {
		text-align: center;
		max-width: 560px;
		margin-inline: auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.pricing-head p {
		color: var(--muted);
	}

	.plans {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: var(--space-5);
		align-items: stretch;
	}

	.plan {
		position: relative;
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		padding: var(--space-6);
	}

	.plan.featured {
		border-color: var(--brand);
		box-shadow: var(--ring-glow);
	}

	.flag {
		position: absolute;
		top: calc(-1 * var(--space-3));
		right: var(--space-5);
		padding: 2px var(--space-3);
		border-radius: var(--radius-pill);
		background: var(--brand);
		color: var(--on-brand);
		font-size: var(--text-2xs);
		font-weight: 700;
	}

	.plan h3 {
		font-size: var(--text-md);
	}

	.price {
		font-size: var(--text-lg);
		font-weight: 800;
		letter-spacing: var(--tracking-tight);
	}

	.note {
		color: var(--muted);
		font-size: var(--text-sm);
		min-height: 2.6em;
	}

	.plan ul {
		list-style: none;
		margin: var(--space-2) 0 var(--space-4);
		padding: 0;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		flex: 1;
	}

	.plan li {
		position: relative;
		padding-inline-start: var(--space-5);
		color: var(--ink-secondary);
		font-size: var(--text-sm);
	}

	.plan li::before {
		content: '✓';
		position: absolute;
		inset-inline-start: 0;
		color: var(--brand);
		font-weight: 700;
	}

	@media (max-width: 859px) {
		.plans {
			grid-template-columns: 1fr;
			max-width: 440px;
			margin-inline: auto;
		}

		.note {
			min-height: 0;
		}
	}
</style>
