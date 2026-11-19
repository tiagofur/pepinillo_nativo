<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import DeviceFrame from './DeviceFrame.svelte';

	type Platform = {
		key: 'mac' | 'iphone' | 'watch' | 'android' | 'wear' | 'web';
		variant: string;
		src: string;
		guide: string;
	};

	const PLATFORMS: Platform[] = [
		{ key: 'mac', variant: 'mac', src: '/guides/img/macos-dashboard.jpg', guide: '/guides/macos.html' },
		{ key: 'iphone', variant: 'iphone', src: '/img/showcase/iphone-plan.jpg', guide: '/guides' },
		{ key: 'watch', variant: 'watch', src: '/img/showcase/watch-tasks.jpg', guide: '/guides' },
		{ key: 'android', variant: 'android', src: '/img/showcase/android-dashboard.jpg', guide: '/guides' },
		{ key: 'wear', variant: 'wear', src: '/img/showcase/wear-stats.jpg', guide: '/guides' },
		{ key: 'web', variant: 'browser', src: '/guides/img/web-05-plan-tabla-es.jpg', guide: '/guides/web.html' }
	];
</script>

<section class="showcase" id="showcase">
	<header class="showcase-head">
		<h2>{t('landing.showcase.title')}</h2>
		<p>{t('landing.showcase.sub')}</p>
	</header>

	<div class="gallery">
		{#each PLATFORMS as p (p.key)}
			<article class="platform platform--{p.key}">
				<DeviceFrame variant={p.variant} src={p.src} alt={t(`landing.showcase.${p.key}.body`)} href={p.guide} />
				<h3>{t(`landing.showcase.${p.key}`)}</h3>
				<p>{t(`landing.showcase.${p.key}.body`)}</p>
				<a class="guide-link" href={p.guide} data-sveltekit-reload={p.guide.endsWith('.html') ? true : undefined}>
					{t('landing.showcase.guide')} <span aria-hidden="true">→</span>
				</a>
			</article>
		{/each}
	</div>
</section>

<style>
	.showcase {
		display: flex;
		flex-direction: column;
		gap: var(--space-10);
	}

	.showcase-head {
		text-align: center;
		max-width: 560px;
		margin-inline: auto;
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.showcase-head p {
		color: var(--muted);
	}

	/* Gallery: natural per-platform sizes, not identical cards */
	.gallery {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		align-items: flex-start;
		gap: var(--space-10) var(--space-12);
	}

	.platform {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		max-width: 340px;
	}

	.platform--mac,
	.platform--web {
		width: min(420px, 100%);
	}

	.platform--iphone,
	.platform--android {
		width: 216px;
	}

	.platform--watch,
	.platform--wear {
		width: 168px;
	}

	.platform h3 {
		font-size: var(--text-base);
		margin-top: var(--space-2);
	}

	.platform p {
		color: var(--muted);
		font-size: var(--text-sm);
	}

	.guide-link {
		color: var(--brand);
		font-weight: 650;
		font-size: var(--text-sm);
	}

	.guide-link:hover {
		text-decoration: none;
		color: var(--brand-strong);
	}

	@media (max-width: 719px) {
		.gallery {
			gap: var(--space-8) var(--space-6);
		}

		.platform--iphone,
		.platform--android {
			width: 180px;
		}

		.platform--watch,
		.platform--wear {
			width: 140px;
		}
	}
</style>
