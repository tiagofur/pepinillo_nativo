<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import logoUrl from '$lib/assets/logo.svg';

	const GUIDE_LIST: { href: string; title: MessageKey; body: MessageKey; emoji: string; ready: boolean }[] = [
		{ href: '/guides/macos.html', title: 'guides.list.macos', body: 'guides.list.macos.body', emoji: '💻', ready: true },
		{ href: '/guides/iphone', title: 'guides.list.iphone', body: 'guides.list.generic.body', emoji: '📱', ready: false },
		{ href: '/guides/watchos', title: 'guides.list.watchos', body: 'guides.list.generic.body', emoji: '⌚️', ready: false },
		{ href: '/guides/android', title: 'guides.list.android', body: 'guides.list.generic.body', emoji: '🤖', ready: false },
		{ href: '/guides/wearos', title: 'guides.list.wearos', body: 'guides.list.generic.body', emoji: '⌚️', ready: false },
		{ href: '/guides/web', title: 'guides.list.web', body: 'guides.list.generic.body', emoji: '🌐', ready: false }
	];
</script>

<svelte:head>
	<title>{t('guides.title')} · Pepinillo</title>
	<meta name="description" content={t('guides.meta')} />
	<link rel="canonical" href="https://pepinillo.app/guides/" />
</svelte:head>

<main class="guides">
	<header class="head">
		<a class="brand" href="/">
			<img src={logoUrl} alt="" width="30" height="30" />
			<span>Pepinillo</span>
		</a>
		<a class="btn btn-soft pressable" href="https://app.pepinillo.app/focus">{t('landing.nav.open')}</a>
	</header>

	<section class="intro rise-in">
		<h1>{t('guides.title')}</h1>
		<p class="muted">{t('guides.intro')}</p>
	</section>

	<section class="list rise-in">
		{#each GUIDE_LIST as g (g.href)}
			{#if g.ready}
				<!-- data-sveltekit-reload: standalone static doc -->
				<a class="card guide pressable" href={g.href} data-sveltekit-reload>
					<span class="emoji">{g.emoji}</span>
					<div>
						<h2>{t(g.title)}</h2>
						<p class="muted">{t(g.body)}</p>
					</div>
					<span class="arrow" aria-hidden="true">→</span>
				</a>
			{:else}
				<div class="card guide soon">
					<span class="emoji">{g.emoji}</span>
					<div>
						<h2>{t(g.title)}</h2>
						<p class="muted">{t('guides.soon')}</p>
					</div>
				</div>
			{/if}
		{/each}
	</section>

	<footer class="foot">
		<a href="/">{t('landing.nav.home')}</a>
		<span class="dot">·</span>
		<span>© 2026 Creapolis</span>
	</footer>
</main>

<style>
	.guides {
		max-width: 760px;
		margin-inline: auto;
		padding: var(--space-5) var(--space-5) calc(var(--space-12) + var(--safe-b));
		display: flex;
		flex-direction: column;
		gap: var(--space-8);
	}

	.head {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		font-weight: 800;
		color: var(--ink);
		font-size: var(--text-md);
	}

	h1 {
		font-size: var(--text-xl);
	}

	.intro {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.muted {
		color: var(--muted);
	}

	.list {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.guide {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-4) var(--space-5);
		color: var(--ink);
	}

	.guide:hover {
		text-decoration: none;
		border-color: var(--brand);
	}

	.guide.soon {
		opacity: 0.6;
	}

	.emoji {
		font-size: 26px;
		flex: none;
	}

	.guide h2 {
		font-size: var(--text-base);
	}

	.guide p {
		font-size: var(--text-sm);
	}

	.guide > div {
		flex: 1;
		min-width: 0;
	}

	.arrow {
		color: var(--brand);
		font-weight: 700;
	}

	.foot {
		display: flex;
		justify-content: center;
		gap: var(--space-2);
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.foot a {
		color: var(--faint);
	}

	.dot {
		color: var(--border-strong);
	}
</style>
