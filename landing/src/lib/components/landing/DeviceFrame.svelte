<script lang="ts">
	/**
	 * DeviceFrame — wraps a real product screenshot in a CSS device chrome.
	 * Variants: mac (screenshot already carries its window chrome), iphone,
	 * watch (round), android, wear (round), browser (web app).
	 */
	let {
		variant = 'mac',
		src,
		alt,
		href,
		class: klass = ''
	}: { variant?: string; src: string; alt: string; href?: string; class?: string } = $props();
</script>

{#if href}
	<a
		class="frame frame--{variant} {klass}"
		href={href}
		data-sveltekit-reload={href.endsWith('.html') ? true : undefined}
	>
		<img {src} {alt} loading="lazy" />
	</a>
{:else}
	<figure class="frame frame--{variant} {klass}">
		<img {src} {alt} loading="lazy" />
	</figure>
{/if}

<style>
	.frame {
		position: relative;
		display: block;
		margin: 0;
		overflow: hidden;
		background: var(--surface);
		box-shadow: var(--shadow-2);
	}

	.frame img {
		display: block;
		width: 100%;
		height: auto;
	}

	/* Mac window: capture includes its own title bar — thin hairline + radius */
	.frame--mac {
		border-radius: 14px;
		border: 1px solid var(--border);
	}

	/* iPhone: black bezel, tall radius. The capture carries its own island. */
	.frame--iphone {
		border-radius: 46px / 56px;
		border: 9px solid #101013;
		background: #101013;
		box-shadow:
			var(--shadow-3),
			0 0 0 1px rgba(255, 255, 255, 0.08);
	}

	.frame--iphone img {
		border-radius: 37px / 47px;
	}

	/* Android: slim bezel, softer corners */
	.frame--android {
		border-radius: 36px;
		border: 8px solid #101013;
		background: #101013;
		box-shadow:
			var(--shadow-3),
			0 0 0 1px rgba(255, 255, 255, 0.08);
	}

	.frame--android img {
		border-radius: 28px;
	}

	/* Round watches (watchOS / Wear OS) */
	.frame--watch,
	.frame--wear {
		border-radius: 50%;
		border: 10px solid #1c1c20;
		background: #1c1c20;
		box-shadow:
			var(--shadow-3),
			0 0 0 1px rgba(255, 255, 255, 0.08);
	}

	.frame--watch img,
	.frame--wear img {
		border-radius: 50%;
	}

	/* Web app: browser chrome */
	.frame--browser {
		border-radius: 14px;
		border: 1px solid var(--border);
	}

	.frame--browser::before {
		content: '';
		display: block;
		height: 34px;
		background: var(--surface-alt);
		border-bottom: 1px solid var(--hairline);
		background-image:
			radial-gradient(circle at 18px 17px, #ff5f57 4.5px, transparent 5px),
			radial-gradient(circle at 38px 17px, #febc2e 4.5px, transparent 5px),
			radial-gradient(circle at 58px 17px, #28c840 4.5px, transparent 5px);
		background-repeat: no-repeat;
	}

	a.frame {
		color: inherit;
	}

	a.frame:hover {
		text-decoration: none;
	}
</style>
