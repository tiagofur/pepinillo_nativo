<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import logoUrl from '$lib/assets/logo.svg';
</script>

<svelte:head>
	<title>Pepinillo — Deep work, planificado y celebrado</title>
</svelte:head>

<main class="landing">
	<div class="glow" aria-hidden="true"></div>

	<section class="hero rise-in">
		<img class="mark" src={logoUrl} alt="Pepinillo" width="96" height="96" />
		<h1 class="wordmark">Pepinillo</h1>
		<p class="tagline">{t('app.tagline')}</p>

		<div class="cta-row">
			<a class="btn btn-primary pressable" href="/focus">{t('landing.openApp')}</a>
		</div>

		<p class="wip">{t('landing.wipNote')}</p>
	</section>

	<footer class="foot">
		<span>Creapolis</span>
		<span class="dot" aria-hidden="true">·</span>
		<span>2026</span>
	</footer>
</main>

<style>
	.landing {
		position: relative;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-12);
		padding: var(--space-6);
		overflow: hidden;
	}

	/* One calm brand glow behind the hero — quiet energy, not a spotlight */
	.glow {
		position: absolute;
		inset: -30% -20% auto;
		height: 120%;
		background:
			radial-gradient(42% 38% at 50% 26%, var(--brand-soft) 0%, transparent 70%),
			radial-gradient(30% 26% at 72% 60%, var(--streak-soft) 0%, transparent 70%);
		pointer-events: none;
	}

	.hero {
		position: relative;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: var(--space-4);
		text-align: center;
	}

	.mark {
		width: 96px;
		height: 96px;
		filter: drop-shadow(var(--shadow-2));
	}

	.wordmark {
		font-size: clamp(2.6rem, 2rem + 3vw, 4rem);
		font-weight: 800;
		letter-spacing: var(--tracking-tighter);
	}

	.tagline {
		max-width: 34ch;
		color: var(--muted);
		font-size: var(--text-md);
	}

	.cta-row {
		display: flex;
		gap: var(--space-3);
		margin-top: var(--space-4);
	}

	.wip {
		margin-top: var(--space-2);
		color: var(--faint);
		font-size: var(--text-sm);
	}

	.foot {
		position: absolute;
		bottom: calc(var(--space-6) + var(--safe-b));
		display: flex;
		gap: var(--space-2);
		color: var(--faint);
		font-size: var(--text-xs);
	}

	.dot {
		color: var(--border-strong);
	}
</style>
