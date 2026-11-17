<script lang="ts">
	import type { Snippet } from 'svelte';
	/**
	 * Mac-style context menu (NSMenu parity): right-click on desktop,
	 * long-press on mobile opens it at the pointer. Material panel r12 with
	 * submenus (hover/click to expand), checkmarks and a destructive role.
	 * Rendering is fully controlled by the owner: pass x/y/items, get
	 * onclose on selection, outside click, scroll, or Escape.
	 */
	export interface ContextMenuItem {
		id: string;
		label?: string;
		kind?: 'item' | 'separator' | 'submenu';
		checked?: boolean;
		destructive?: boolean;
		disabled?: boolean;
		children?: ContextMenuItem[];
		onselect?: () => void;
	}

	let {
		x,
		y,
		items,
		onclose
	}: { x: number; y: number; items: ContextMenuItem[]; onclose: () => void } = $props();

	let menuEl = $state<HTMLDivElement | null>(null);
	let openSubmenu = $state<string | null>(null);
	// Clamped position, resolved inside the effect (x/y are the fresh pointer
	// coords of each mount — the owner recreates the menu per invocation).
	let pos = $state({ left: 0, top: 0 });

	// Synchronous clamp: $effect runs after the DOM insert, so menuEl is
	// already bound (rAF would never fire for background tabs). Re-runs if
	// the pointer coords or the element change.
	$effect(() => {
		if (!menuEl) return;
		const r = menuEl.getBoundingClientRect();
		const margin = 8;
		const left = Math.max(margin, Math.min(x, window.innerWidth - r.width - margin));
		const top = Math.max(margin, Math.min(y, window.innerHeight - r.height - margin));
		pos = { left, top };
	});

	function pick(item: ContextMenuItem): void {
		if (item.disabled || item.kind === 'separator' || item.kind === 'submenu') return;
		item.onselect?.();
		onclose();
	}

	function onKeydown(e: KeyboardEvent): void {
		if (e.key === 'Escape') {
			e.preventDefault();
			onclose();
		}
	}
</script>

<svelte:window onkeydown={onKeydown} onscroll={() => onclose()} onscrollcapture={() => onclose()} />

<!-- a11y waiver: pointer-positioned menu; keyboard users keep their existing
	 shortcuts (row selection + inspector + title edit) and Escape closes. -->
<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="ctx-scrim" role="presentation" onclick={onclose} onscroll={() => onclose()}>
	<div
		class="ctx material-panel"
		bind:this={menuEl}
		style="left: {pos.left}px; top: {pos.top}px;"
		role="menu"
		tabindex="-1"
		onclick={(e) => e.stopPropagation()}
	>
		{#each items as item (item.id)}
			{#if item.kind === 'separator'}
				<hr class="sep" />
			{:else if item.kind === 'submenu' && item.children}
				<div
					class="entry has-sub"
					class:is-open={openSubmenu === item.id}
					role="menuitem"
					aria-haspopup="menu"
					aria-expanded={openSubmenu === item.id}
					tabindex="0"
					onkeydown={(e) => e.key === 'Enter' && (openSubmenu = openSubmenu === item.id ? null : item.id)}
					onmouseenter={() => (openSubmenu = item.id)}
					onclick={() => (openSubmenu = openSubmenu === item.id ? null : item.id)}
				>
					<span class="label" class:destructive={item.destructive}>{item.label}</span>
					<span class="chev" aria-hidden="true">›</span>
					{#if openSubmenu === item.id}
						<div class="submenu material-panel" role="menu">
							{#each item.children as child (child.id)}
								<button
									class="entry child"
									class:destructive={child.destructive}
									class:disabled={child.disabled}
									role="menuitem"
									disabled={child.disabled}
									onclick={() => pick(child)}
								>
									<span class="checkmark">{child.checked ? '✓' : ''}</span>
									<span class="label">{child.label}</span>
								</button>
							{/each}
						</div>
					{/if}
				</div>
			{:else}
				<button
					class="entry"
					class:destructive={item.destructive}
					class:disabled={item.disabled}
					role="menuitem"
					disabled={item.disabled}
					onclick={() => pick(item)}
				>
					<span class="checkmark">{item.checked ? '✓' : ''}</span>
					<span class="label">{item.label}</span>
				</button>
			{/if}
		{/each}
	</div>
</div>

<style>
	.ctx-scrim {
		position: fixed;
		inset: 0;
		z-index: 80;
	}

	.ctx {
		position: fixed;
		min-width: 200px;
		padding: var(--space-1);
		z-index: 81;
		animation: ctx-in var(--dur-fast) var(--ease-out-quint) both;
	}

	.entry {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		min-height: 30px;
		padding: 0 var(--space-3);
		border: none;
		background: none;
		border-radius: var(--radius-sm);
		color: var(--ink);
		font-size: var(--text-sm);
		font-weight: 500;
		text-align: start;
		cursor: pointer;
	}

	.entry:hover,
	.entry.is-open {
		background: var(--brand);
		color: var(--on-brand);
	}

	.entry:hover .chev,
	.entry.is-open .chev {
		color: var(--on-brand);
	}

	.entry.destructive {
		color: var(--danger);
	}

	.entry.destructive:hover {
		background: var(--danger);
		color: #ffffff;
	}

	.entry.disabled {
		opacity: 0.4;
		cursor: default;
	}

	.entry.disabled:hover {
		background: none;
		color: var(--ink);
	}

	.checkmark {
		width: 14px;
		flex: none;
		color: var(--brand);
	}

	.entry:hover .checkmark,
	.entry.is-open .checkmark {
		color: var(--on-brand);
	}

	.label {
		flex: 1;
		white-space: nowrap;
	}

	.chev {
		color: var(--muted);
		font-weight: 700;
	}

	.has-sub {
		position: relative;
	}

	/* Submenus always stack INLINE below their entry (GitHub/Linear pattern):
	 * a floating 180px panel can leave the viewport near any edge, on any
	 * screen size — inline stacking is in-viewport by construction. */
	.submenu {
		min-width: 0;
		width: 100%;
		max-height: min(280px, 40vh);
		overflow-y: auto;
		padding: var(--space-1);
		box-shadow: none;
		margin-top: var(--space-1);
	}

	/* When a submenu opens, the entry drops its row layout so the inline
	 * submenu stacks BELOW the label (it would otherwise be a flex row
	 * item beside it). The chevron implied a flyout that no longer exists. */
	.entry.has-sub.is-open {
		display: block;
	}

	.entry.has-sub.is-open .chev {
		display: none;
	}

	.entry.has-sub.is-open .submenu {
		min-width: 0;
		width: 100%;
		max-height: min(280px, 40vh);
		box-shadow: none;
		margin-top: var(--space-1);
	}

	.sep {
		border: 0;
		border-top: 1px solid var(--hairline);
		margin: var(--space-1) var(--space-2);
	}

	@keyframes ctx-in {
		from {
			opacity: 0;
			transform: scale(0.96);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.ctx {
			animation: none;
		}
	}
</style>
