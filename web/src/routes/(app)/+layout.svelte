<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import { app } from '$lib/stores/app.svelte';
	import { auth } from '$lib/stores/auth.svelte';
	import { plan } from '$lib/stores/plan.svelte';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import Icon from '$lib/design/Icon.svelte';
	import { msUntilNextFire } from '$lib/domain/notifications/reminder';
	import QuickCapture from '$lib/features/plan/QuickCapture.svelte';
	import Toasts from '$lib/design/Toasts.svelte';
	import logoUrl from '$lib/assets/logo.svg';
	import type { PlanFilter } from '$lib/domain/tasks/plan';

	type PlanCommand = 'pepinillo:plan-search' | 'pepinillo:plan-new-task' | 'pepinillo:plan-inspector';

	onMount(() => {
		void (async () => {
			await app.init();
			// Restore the server session (tier → premium gates) on every route.
			await auth.init();
			// macOS parity: open on the user's default section.
			if (page.url.pathname === '/focus' && app.prefs.defaultSection !== 'focus') {
				const { goto } = await import('$app/navigation');
				await goto(`/${app.prefs.defaultSection}`);
			}
			scheduleDailyReminder();
		})();
	});

	// Native parity: ⌘1/⌘2/⌘3 jump to Focus/Plan/Dashboard (Mac AppCommands),
	// ⌘F plan search, ⌘N new task, ⌘⌥I inspector. (⌘N/⌘⌥I are browser-reserved
	// in some engines — the toolbar buttons are the reliable path.)
	// e.code (physical key) so Alt-composed keys on macOS still match.
	function onCommandKey(e: KeyboardEvent): void {
		if (!(e.metaKey || e.ctrlKey)) return;
		if (e.key >= '1' && e.key <= '3') {
			e.preventDefault();
			const routes: Record<string, '/focus' | '/plan' | '/dashboard'> = {
				1: '/focus',
				2: '/plan',
				3: '/dashboard'
			};
			const route = routes[e.key];
			if (route) void import('$app/navigation').then(({ goto }) => goto(route));
			return;
		}
		if (e.code === 'KeyF' && !e.altKey && !e.shiftKey) {
			e.preventDefault();
			void planThenDispatch('pepinillo:plan-search');
		} else if (e.code === 'KeyN' && !e.altKey && !e.shiftKey) {
			e.preventDefault();
			void planThenDispatch('pepinillo:plan-new-task');
		} else if (e.code === 'KeyI' && e.altKey) {
			e.preventDefault();
			void planThenDispatch('pepinillo:plan-inspector');
		}
	}

	/**
	 * Navigate to Plan (if needed) and raise a page-level command.
	 * Cross-route: park the command on `window.pepinilloPlanCommand` — the
	 * Plan page consumes it on mount (goto resolves after mount). If mount
	 * somehow raced, the fallback dispatch fires once; the parked value is
	 * checked before dispatching so the command never executes twice.
	 * Already on Plan: dispatch directly (nothing parked, nothing leaks).
	 */
	async function planThenDispatch(command: PlanCommand): Promise<void> {
		const w = window as unknown as { pepinilloPlanCommand?: PlanCommand };
		if (!page.url.pathname.startsWith('/plan')) {
			w.pepinilloPlanCommand = command;
			const { goto } = await import('$app/navigation');
			await goto('/plan');
			if (w.pepinilloPlanCommand === command) {
				delete w.pepinilloPlanCommand;
				window.dispatchEvent(new CustomEvent(command));
			}
		} else {
			window.dispatchEvent(new CustomEvent(command));
		}
	}

	window.addEventListener('keydown', onCommandKey);

	// Daily reminder (native parity): one Notification per day at the configured time.
	function scheduleDailyReminder(): void {
		if (!app.prefs.notificationsEnabled || !app.prefs.dailyReminderEnabled) return;
		if (!('Notification' in window) || Notification.permission !== 'granted') return;
		const ms = msUntilNextFire(app.prefs.dailyReminderHour, app.prefs.dailyReminderMinute);
		setTimeout(() => {
			try {
				new Notification('Pepinillo', { body: '⏰ Hora de enfocarte — tu huerto espera' });
			} catch {
				/* non-fatal */
			}
			scheduleDailyReminder();
		}, ms);
	}

	// Mac sidebar model: Focus → Plan filters (MacPlanFilter) → Dashboard.
	const PLAN_ROWS: { id: PlanFilter; key: MessageKey; icon: string }[] = [
		{ id: 'all', key: 'plan.filter.all', icon: 'tray' },
		{ id: 'today', key: 'plan.filter.today', icon: 'sun' },
		{ id: 'upcoming', key: 'plan.filter.upcoming', icon: 'calendar' },
		{ id: 'completed', key: 'plan.filter.completed', icon: 'check-circle' }
	];

	const TABS: { path: string; key: MessageKey; icon: string }[] = [
		{ path: '/focus', key: 'nav.focus', icon: 'focus' },
		{ path: '/plan', key: 'nav.plan', icon: 'plan' },
		{ path: '/dashboard', key: 'nav.dashboard', icon: 'dashboard' },
		{ path: '/account', key: 'nav.account', icon: 'account' }
	];

	let onPlan = $derived(page.url.pathname.startsWith('/plan'));
	let current = $derived(page.url.pathname);

	// Sidebar footer identity: initial avatar + name/email when signed in.
	let displayName = $derived(auth.user?.name || auth.user?.email || t('nav.account'));
	let displayMail = $derived(auth.user?.email ?? '');
	let avatarInitial = $derived(displayName.trim().charAt(0).toUpperCase() || 'P');

	let { children } = $props();
</script>

<div class="shell">
	<!-- Desktop sidebar / tablet rail (MacAppView model) -->
	<aside class="app-sidebar">
		<a class="brand pressable" href="/focus" aria-label="Pepinillo">
			<img src={logoUrl} alt="" width="34" height="34" />
			<span class="brand-name">Pepinillo</span>
		</a>

		<nav class="nav" aria-label={t('app.name')}>
			<a
				class="nav-row pressable"
				href="/focus"
				aria-current={page.url.pathname.startsWith('/focus') ? 'page' : undefined}
				class:is-active={page.url.pathname.startsWith('/focus')}
			>
				<Icon name="focus" size={16} />
				<span class="nav-label">{t('nav.focus')}</span>
			</a>

			<span class="nav-section nav-label" aria-hidden="true">{t('nav.plan')}</span>
			{#each PLAN_ROWS as row (row.id)}
				<a
					class="nav-row pressable"
					href="/plan"
					aria-current={onPlan && plan.filter === row.id ? 'page' : undefined}
					class:is-active={onPlan && plan.filter === row.id}
					onclick={() => plan.setFilter(row.id)}
				>
					<Icon name={row.icon} size={16} />
					<span class="nav-label">{t(row.key)}</span>
				</a>
			{/each}

			<a
				class="nav-row pressable"
				href="/dashboard"
				aria-current={page.url.pathname.startsWith('/dashboard') ? 'page' : undefined}
				class:is-active={page.url.pathname.startsWith('/dashboard')}
			>
				<Icon name="dashboard" size={16} />
				<span class="nav-label">{t('nav.dashboard')}</span>
			</a>
		</nav>

		<div class="spacer"></div>

		<!-- Account footer row (Mac sidebar footer) -->
		<footer class="sidebar-footer">
			<a
				class="account-row pressable"
				href="/account"
				aria-current={page.url.pathname.startsWith('/account') ? 'page' : undefined}
				class:is-active={page.url.pathname.startsWith('/account')}
			>
				<span class="avatar" aria-hidden="true">{avatarInitial}</span>
				<span class="account-meta">
					<span class="account-name">{displayName}</span>
					{#if displayMail}
						<span class="account-mail">{displayMail}</span>
					{/if}
				</span>
			</a>
			<a class="gear-btn pressable" href="/account#settings" aria-label={t('account.settings')}>
				<Icon name="gear" size={16} />
			</a>
		</footer>
	</aside>

	<main class="content">
		{@render children?.()}
	</main>
</div>

<QuickCapture />
<Toasts />

<!-- Mobile bottom tab bar -->
<nav class="tabbar tabbar-fixed" aria-label={t('app.name')}>
	{#each TABS as item (item.path)}
		<a
			class="tabbar-item pressable"
			href={item.path}
			aria-current={current?.startsWith(item.path) ? 'page' : undefined}
			class:is-active={current?.startsWith(item.path)}
		>
			<Icon name={item.icon} size={24} />
			<span>{t(item.key)}</span>
		</a>
	{/each}
</nav>

<style>
	/* Mac window model: the shell is viewport-height and NEVER scrolls as a
	 * document — the sidebar (menu + account footer) stays fully visible and
	 * only the content column scrolls. */
	.shell {
		display: grid;
		grid-template-columns: var(--sidebar-w) 1fr;
		grid-template-rows: 100dvh;
		height: 100dvh;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: var(--touch-target);
		padding: 0 var(--space-2) var(--space-2);
		color: var(--ink);
		font-weight: 800;
		letter-spacing: var(--tracking-tight);
		font-size: var(--text-base);
	}

	.brand:hover {
		text-decoration: none;
	}

	.nav {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.spacer {
		flex: 1;
	}

	.content {
		min-width: 0;
		/* No top padding: sticky descendants (pane toolbars) anchor flush
		 * to the scroll container's top edge — page roots carry the rhythm */
		padding: 0 var(--space-8) calc(var(--space-10) + var(--safe-b));
		max-width: var(--content-max);
		margin: 0 auto;
		width: 100%;
		height: 100%;
		overflow-y: auto;
		scrollbar-width: thin;
		-webkit-overflow-scrolling: touch;
	}

	/* Tablet: rail with icons only */
	@media (max-width: 1023px) {
		.shell {
			grid-template-columns: var(--rail-w) 1fr;
		}

		.brand-name,
		.nav-label,
		.account-meta {
			display: none;
		}

		.nav-row {
			justify-content: center;
			padding: 0;
		}

		.nav-section {
			display: none;
		}

		.brand {
			justify-content: center;
			padding-inline: 0;
		}

		.sidebar-footer {
			flex-direction: column;
		}

		.account-row {
			justify-content: center;
		}

		.content {
			padding: 0 var(--space-5) calc(var(--space-10) + var(--safe-b));
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
			padding: 0 var(--space-4) calc(var(--tabbar-h) + var(--safe-b) + var(--space-8));
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
