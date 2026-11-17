<script lang="ts">
	/**
	 * iOS/macOS-style toggle switch (UISwitch parity).
	 * Pill track + spring knob; replaces native checkboxes in settings.
	 */
	let {
		checked,
		onchange,
		label,
		disabled = false
	}: {
		checked: boolean;
		onchange: (next: boolean) => void;
		label?: string;
		disabled?: boolean;
	} = $props();
</script>

<button
	class="switch-ios"
	class:is-on={checked}
	type="button"
	role="switch"
	aria-checked={checked}
	aria-label={label}
	{disabled}
	onclick={() => onchange(!checked)}
>
	<span class="knob" aria-hidden="true"></span>
</button>

<style>
	.switch-ios {
		flex: none;
		width: 51px;
		height: 31px;
		border-radius: var(--radius-pill);
		border: none;
		padding: 2px;
		background: var(--surface-sunken);
		border: 1px solid var(--border);
		cursor: pointer;
		transition: background var(--dur-base) var(--ease-out-quint);
	}

	.switch-ios.is-on {
		background: var(--brand);
		border-color: transparent;
	}

	.switch-ios:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.knob {
		display: block;
		width: 25px;
		height: 25px;
		border-radius: 50%;
		background: #fff;
		box-shadow:
			0 2px 6px rgba(0, 0, 0, 0.18),
			0 0 1px rgba(0, 0, 0, 0.12);
		transition: transform var(--dur-base) var(--spring);
	}

	.is-on .knob {
		transform: translateX(20px);
	}

	@media (prefers-reduced-motion: reduce) {
		.knob {
			transition: none;
		}
	}
</style>
