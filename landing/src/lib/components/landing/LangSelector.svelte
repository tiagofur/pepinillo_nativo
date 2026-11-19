<script lang="ts">
	import { currentLocale, setLocale } from '$lib/i18n/i18n.svelte';
	import type { LocaleCode } from '$lib/domain/entities/types';

	const LOCALES: { code: LocaleCode; label: string }[] = [
		{ code: 'es', label: 'ES' },
		{ code: 'en', label: 'EN' },
		{ code: 'pt', label: 'PT' }
	];
</script>

<div class="lang" role="group" aria-label="Idioma / Language">
	{#each LOCALES as l (l.code)}
		<button
			class="lang-btn"
			aria-pressed={currentLocale() === l.code}
			onclick={() => setLocale(l.code)}
		>
			{l.label}
		</button>
	{/each}
</div>

<style>
	.lang {
		display: inline-flex;
		align-items: center;
		gap: 2px;
		padding: 3px;
		border-radius: var(--radius-pill);
		background: var(--surface-alt);
	}

	.lang-btn {
		min-width: 34px;
		min-height: 28px;
		padding: 0 var(--space-2);
		border: none;
		border-radius: var(--radius-pill);
		background: transparent;
		color: var(--muted);
		font-size: var(--text-2xs);
		font-weight: 700;
		letter-spacing: 0.04em;
		cursor: pointer;
		transition:
			background-color var(--dur-fast) var(--ease-out-quint),
			color var(--dur-fast) var(--ease-out-quint);
	}

	.lang-btn:hover {
		color: var(--ink);
	}

	.lang-btn[aria-pressed='true'] {
		background: var(--surface);
		color: var(--brand);
		box-shadow: var(--shadow-1);
	}
</style>
