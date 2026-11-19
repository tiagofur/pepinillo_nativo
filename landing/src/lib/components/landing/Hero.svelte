<script lang="ts">
	import { t } from '$lib/i18n/i18n.svelte';
	import { APP_STORE_URL, PLAY_STORE_URL, WEB_APP_URL } from './links';
	import DeviceFrame from './DeviceFrame.svelte';
</script>

<section class="hero">
	<div class="hero-copy">
		<p class="kicker">{t('landing.kicker')}</p>
		<h1>{t('landing.hero.title')}</h1>
		<p class="lede">{t('landing.hero.sub')}</p>
		<div class="cta-row">
			<a class="btn btn-primary pressable" href={WEB_APP_URL}>{t('landing.cta.web')}</a>
			<a class="btn btn-outline pressable" href={APP_STORE_URL} rel="noopener">
				<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
					<path
						fill="currentColor"
						d="M16.7 12.9c0-2.4 2-3.6 2.1-3.7-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.9-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.3 1.2 9.7.8 1.2 1.8 2.5 3.1 2.4 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.6-1-2.7-3.7zM14.4 5.6c.7-.8 1.1-1.9 1-3.1-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.9-1 3 1.1.1 2.2-.6 2.9-1.4z"
					/>
				</svg>
				{t('landing.hero.cta.ios')}
			</a>
			<a class="btn btn-outline pressable" href={PLAY_STORE_URL} rel="noopener">
				<svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true">
					<path
						fill="currentColor"
						d="M3.6 2.3c-.3.2-.5.5-.5 1v17.4c0 .5.2.8.5 1l9.3-9.7L3.6 2.3zM14.6 12l3-3.1-9.5-5.4c-.3-.2-.6-.2-.9-.1L14.6 12zm0 0 3 3.1-9.5 5.4c-.3.2-.6.2-.9.1L14.6 12zm4.4-1.2 2.1-1.2c1-.6 1-2 0-2.6l-2.3-1.3-2.5 2.6 2.7 2.5zm0 2.4-2.7 2.5 2.5 2.6 2.3-1.3c1-.6 1-2 0-2.6l-2.1-1.2z"
					/>
				</svg>
				{t('landing.hero.cta.android')}
			</a>
		</div>
		<p class="hint">{t('landing.hero.hint')}</p>
		<p class="hint">{t('landing.download.pikle')}</p>
	</div>

	<div class="scene" role="img" aria-label={t('landing.hero.scene.label')}>
		<div class="sc-iphone">
			<DeviceFrame variant="iphone" src="/guides/img/iphone-03-foco-corriendo.jpg" alt={t('landing.hero.scene.iphone')} />
		</div>
		<div class="sc-mac">
			<DeviceFrame
				variant="mac"
				src="/guides/img/macos-focus-running.jpg"
				alt={t('landing.hero.scene.mac')}
				loading="eager"
			/>
		</div>
		<div class="sc-watch">
			<DeviceFrame variant="watch" src="/guides/img/watchos-01-timer.jpg" alt={t('landing.hero.scene.watch')} />
		</div>
	</div>

	<div class="scene-strip">
		<div class="strip-android">
			<DeviceFrame variant="android" src="/img/hero/android-focus.jpg" alt={t('landing.hero.scene.android')} />
		</div>
		<div class="strip-web">
			<DeviceFrame variant="browser" src="/guides/img/web-02-foco-corriendo.jpg" alt={t('landing.hero.scene.web')} />
		</div>
	</div>
</section>

<style>
	.hero {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		padding: var(--space-12) var(--space-4) var(--space-8);
	}

	.hero-copy {
		max-width: 720px;
		display: flex;
		flex-direction: column;
		align-items: center;
	}

	.kicker {
		color: var(--brand);
		font-weight: 700;
		font-size: var(--text-sm);
		text-transform: uppercase;
		letter-spacing: 0.08em;
	}

	h1 {
		font-size: var(--text-display);
		font-weight: 800;
		letter-spacing: var(--tracking-tighter);
		margin: var(--space-3) 0 var(--space-4);
		text-wrap: balance;
	}

	.lede {
		font-size: var(--text-md);
		color: var(--muted);
		max-width: 58ch;
		margin-bottom: var(--space-6);
	}

	.cta-row {
		display: flex;
		gap: var(--space-3);
		flex-wrap: wrap;
		justify-content: center;
	}

	.hint {
		margin-top: var(--space-3);
		color: var(--faint);
		font-size: var(--text-xs);
	}

	/* Ecosystem scene: iPhone — Mac — Watch, organic offsets */
	.scene {
		position: relative;
		display: grid;
		grid-template-columns: 1fr minmax(0, 620px) 1fr;
		align-items: center;
		justify-items: center;
		gap: var(--space-8);
		width: 100%;
		max-width: 1040px;
		margin-top: var(--space-12);
	}

	/* soft ground shadow so the light Mac window sits in the scene */
	.scene::after {
		content: '';
		position: absolute;
		left: 50%;
		bottom: -40px;
		width: 76%;
		height: 84px;
		transform: translateX(-50%);
		background: radial-gradient(50% 100% at 50% 50%, color-mix(in srgb, var(--ink) 20%, transparent), transparent 70%);
		filter: blur(42px);
		pointer-events: none;
	}

	.sc-iphone {
		width: 100%;
		max-width: 186px;
		justify-self: end;
		transform: translateY(22px);
	}

	.sc-mac {
		width: 100%;
		box-shadow: var(--shadow-3);
		z-index: 1;
	}

	.sc-watch {
		width: 100%;
		max-width: 154px;
		justify-self: start;
		transform: translateY(16px);
	}

	/* Companion strip: Android + Web */
	.scene-strip {
		display: flex;
		align-items: flex-end;
		justify-content: center;
		gap: var(--space-10);
		width: 100%;
		max-width: 880px;
		margin-top: var(--space-10);
	}

	.strip-android {
		width: 148px;
		flex: none;
	}

	.strip-web {
		width: min(420px, 50vw);
		min-width: 260px;
	}

	@media (max-width: 859px) {
		h1 {
			font-size: clamp(2rem, 8.4vw, 2.75rem);
		}

		.scene {
			grid-template-columns: 1fr;
			gap: var(--space-6);
		}

		.sc-iphone,
		.sc-watch {
			display: none;
		}

		.scene-strip {
			gap: var(--space-6);
		}

		.strip-android {
			width: 128px;
		}
	}

	@media (max-width: 559px) {
		.strip-web {
			min-width: 0;
			flex: 1;
		}

		.hero {
			padding-inline: var(--space-3);
		}
	}
</style>
