<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { app } from '$lib/stores/app.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Icon from '$lib/design/Icon.svelte';
	import QuickCapture from '$lib/features/plan/QuickCapture.svelte';
	import logoUrl from '$lib/assets/logo.svg';

	onMount(() => {
		void app.init();
	});

	const NAV: { path: string; key: MessageKey; icon: string }[] = [
		{ path: '/focus', key: 'nav.focus', icon: 'focus' },
		{ path: '/plan', key: 'nav.plan', icon: 'plan' },
		{ path: '/dashboard', key: 'nav.dashboard', icon: 'dashboard' }
	];

	const TABS: { path: string; key: MessageKey; icon: string }[] = [
		...NAV,
		{ path: '/account', key: 'nav.account', icon: 'account' }
	];

	let current = $derived(page.url.pathname);
	let { children } = $props();
</script>

<div class="shell">
	<!-- Desktop sidebar / tablet rail -->
	<aside class="app-sidebar">
		<a class="brand pressable" href="/focus" aria-label="Pepinillo">
			<img src={logoUrl} alt="" width="34" height="34" />
			<span class="brand-name">Pepinillo</span>
		</a>

		<nav class="nav" aria-label={t('app.name')}>
			{#each NAV as item (item.path)}
				<a
					class="nav-item pressable"
					href={item.path}
					aria-current={current.startsWith(item.path) ? 'page' : undefined}
					class:is-active={current.startsWith(item.path)}
				>
					<Icon name={item.icon} />
					<span class="nav-label">{t(item.key)}</span>
				</a>
			{/each}
		</nav>

		<div class="spacer"></div>

		<a
			class="nav-item pressable"
			href="/account"
			aria-current={current.startsWith('/account') ? 'page' : undefined}
			class:is-active={current.startsWith('/account')}
		>
			<Icon name="account" />
			<span class="nav-label">{t('nav.account')}</span>
		</a>
	</aside>

	<main class="content">
		{@render children?.()}
	</main>
</div>

<QuickCapture />

<!-- Mobile bottom tab bar -->
<nav class="tabbar tabbar-fixed" aria-label={t('app.name')}>
	{#each TABS as item (item.path)}
		<a
			class="tabbar-item pressable"
			href={item.path}
			aria-current={current.startsWith(item.path) ? 'page' : undefined}
			class:is-active={current.startsWith(item.path)}
		>
			<Icon name={item.icon} size={24} />
			<span>{t(item.key)}</span>
		</a>
	{/each}
</nav>

<style>
	.shell {
		display: grid;
		grid-template-columns: var(--sidebar-w) 1fr;
		min-height: 100dvh;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: var(--space-3);
		min-height: var(--touch-target);
		padding: 0 var(--space-3) var(--space-2);
		color: var(--ink);
		font-weight: 800;
		letter-spacing: var(--tracking-tight);
		font-size: var(--text-md);
	}

	.brand:hover {
		text-decoration: none;
	}

	.nav {
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
	}

	.spacer {
		flex: 1;
	}

	.content {
		min-width: 0;
		padding: var(--space-8) var(--space-8) calc(var(--space-10) + var(--safe-b));
		max-width: var(--content-max);
		margin: 0 auto;
		width: 100%;
	}

	/* Tablet: rail with icons only */
	@media (max-width: 1023px) {
		.shell {
			grid-template-columns: var(--rail-w) 1fr;
		}

		.brand-name,
		.nav-label {
			display: none;
		}

		.nav-item {
			justify-content: center;
			padding: 0;
		}

		.brand {
			justify-content: center;
			padding-inline: 0;
		}

		.content {
			padding: var(--space-6) var(--space-5) calc(var(--space-10) + var(--safe-b));
		}
	}

	/* Mobile: no sidebar, fixed bottom tab bar */
	@media (max-width: 767px) {
		.shell {
			grid-template-columns: 1fr;
		}

		.app-sidebar {
			display: none;
		}

		.content {
			padding: var(--space-5) var(--space-4) calc(var(--tabbar-h) + var(--safe-b) + var(--space-8));
		}
	}

	.tabbar-fixed {
		position: fixed;
		inset: auto 0 0 0;
		z-index: 50;
	}

	@media (min-width: 768px) {
		.tabbar-fixed {
			display: none;
		}
	}
</style>
