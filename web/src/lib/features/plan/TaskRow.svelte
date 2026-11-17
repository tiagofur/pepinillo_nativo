<script lang="ts">
	import type { Task } from '$lib/domain/entities/types';
	import { subtaskProgress } from '$lib/domain/tasks/plan';
	import { t } from '$lib/i18n/i18n.svelte';
	import type { MessageKey } from '$lib/i18n/messages';
	import { localDateKey } from '$lib/domain/tasks/recurrence';

	let {
		task,
		selected,
		onselect,
		ontoggle,
		onfocus,
		dragging = false,
		ondragstart,
		ondragover,
		ondrop,
		oncontext
	}: {
		task: Task;
		selected: boolean;
		onselect: () => void;
		ontoggle: () => void;
		onfocus: () => void;
		dragging?: boolean;
		ondragstart?: () => void;
		ondragover?: (e: DragEvent) => void;
		ondrop?: () => void;
		oncontext?: (x: number, y: number) => void;
	} = $props();

	// Mac parity: long-press opens the row context menu on touch.
	let pressTimer: ReturnType<typeof setTimeout> | null = null;
	let pressX = 0;
	let pressY = 0;
	// The gesture's synthesized click must not instantly close the menu.
	let suppressClick = false;

	function touchStart(e: TouchEvent): void {
		if (!oncontext) return;
		if (e.touches.length !== 1) {
			touchCancel();
			return;
		}
		const t = e.touches[0];
		if (!t) return;
		pressX = t.clientX;
		pressY = t.clientY;
		pressTimer = setTimeout(() => {
			pressTimer = null;
			suppressClick = true;
			setTimeout(() => (suppressClick = false), 450);
			oncontext?.(pressX, pressY);
		}, 500);
	}

	// Movement with a 10px slop: finger jitter never cancels the press.
	function touchMove(e: TouchEvent): void {
		if (!pressTimer) return;
		const t = e.touches[0];
		if (!t) return;
		if (Math.abs(t.clientX - pressX) > 10 || Math.abs(t.clientY - pressY) > 10) touchCancel();
	}

	function touchCancel(): void {
		if (pressTimer) {
			clearTimeout(pressTimer);
			pressTimer = null;
		}
	}

	function onClickCapture(e: MouseEvent): void {
		if (suppressClick) {
			e.stopPropagation();
			e.preventDefault();
		}
	}

	// Destructors: a pending press must not fire for an unmounted row.
	$effect(() => {
		return () => {
			if (pressTimer) clearTimeout(pressTimer);
		};
	});

	// Native PriorityColors.kt: fixed semantic colors (not theme-dependent).
	const PRIORITY_COLOR: Record<string, string> = {
		none: 'transparent',
		low: '#1e88e5',
		medium: '#fb8c00',
		high: '#e53935'
	};

	// Native EnergyColors.kt: deep=primary, regular=tertiary, light=secondary
	// mapped to the shared brand/grammar palette.
	const ENERGY_COLOR: Record<string, string> = {
		deep: 'var(--brand)',
		shallow: 'var(--mode-flowtime)',
		admin: 'var(--streak)'
	};

	const ENERGY_LABEL: Record<string, MessageKey> = {
		deep: 'plan.energy.deep',
		shallow: 'plan.energy.shallow',
		admin: 'plan.energy.admin'
	};

	let dueLabel = $derived.by(() => {
		if (!task.dueDate) return '';
		const todayKey = localDateKey(new Date());
		if (task.dueDate === todayKey) return t('plan.due.today');
		if (task.dueDate < todayKey) return t('plan.due.overdue');
		return task.dueDate;
	});

	let subs = $derived(subtaskProgress(task));
</script>

<li
	class="row"
	class:selected
	class:dragging
	draggable="true"
	ondragstart={ondragstart}
	ondragover={ondragover}
	ondrop={ondrop}
	ontouchstart={touchStart}
	ontouchend={touchCancel}
	ontouchmove={touchMove}
	ontouchcancel={touchCancel}
	onclickcapture={onClickCapture}
	oncontextmenu={(e) => oncontext && e.preventDefault()}
>
	<button
		class="check pressable"
		aria-label={t('plan.complete')}
		aria-pressed={task.status === 'completed'}
		onclick={ontoggle}
	></button>

	<button class="main pressable" onclick={onselect}>
		<span class="priority" style="background: {PRIORITY_COLOR[task.priority]}"></span>
		<span class="title" class:done={task.status === 'completed'}>{task.title}</span>
		<span class="meta">
			{#if subs.total > 0}
				<span class="pill">{subs.done}/{subs.total}</span>
			{/if}
			{#if task.estimatedPomodoros > 0}
				<span class="pill nums">🍅 {task.completedPomodoros ?? 0}/{task.estimatedPomodoros}</span>
			{/if}
			{#if task.recurrenceRule}
				<span class="pill">🔁</span>
			{/if}
			{#if dueLabel}
				<span class="pill due" class:overdue={task.dueDate && task.dueDate < localDateKey(new Date())}>{dueLabel}</span>
			{/if}
			<span class="pill energy" style="color: {ENERGY_COLOR[task.energy]}; background: color-mix(in srgb, {ENERGY_COLOR[task.energy]} 10%, transparent)">{t(ENERGY_LABEL[task.energy])}</span>
		</span>
	</button>

	<button
		class="focus-btn btn-icon pressable"
		aria-label={t('plan.focusTask')}
		title={t('plan.focusTask')}
		onclick={onfocus}
	>▶</button>
</li>

<style>
	.row {
		user-select: none;
		-webkit-user-select: none;
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 56px;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-md);
		border: 1px solid transparent;
		transition: background-color var(--dur-fast) var(--ease-out-quint);
	}

	.row:hover {
		background: var(--surface-alt);
	}

	.row.selected {
		background: var(--brand-softer);
		border-color: var(--brand-soft);
	}

	.row.dragging {
		opacity: 0.45;
	}

	.check {
		flex: none;
		width: 22px;
		height: 22px;
		border-radius: 50%;
		border: 2px solid var(--border-strong);
		background: transparent;
		cursor: pointer;
		transition:
			background-color var(--dur-fast) var(--ease-out-quint),
			border-color var(--dur-fast) var(--ease-out-quint);
	}

	.check:hover {
		border-color: var(--brand);
	}

	.check[aria-pressed='true'] {
		background: var(--brand);
		border-color: var(--brand);
	}

	.main {
		flex: 1;
		min-width: 0;
		display: flex;
		align-items: center;
		gap: var(--space-2);
		min-height: 44px;
		background: none;
		border: none;
		cursor: pointer;
		text-align: start;
		padding: 0;
	}

	.priority {
		flex: none;
		width: 8px;
		height: 8px;
		border-radius: 50%;
	}

	.title {
		font-weight: 550;
		color: var(--ink);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.title.done {
		text-decoration: line-through;
		color: var(--muted);
	}

	.meta {
		display: flex;
		gap: var(--space-1);
		flex: none;
	}

	.pill {
		font-size: var(--text-2xs);
		font-weight: 600;
		color: var(--muted);
		background: var(--surface-alt);
		border-radius: var(--radius-pill);
		padding: 2px 8px;
		white-space: nowrap;
	}

	.pill.energy {
		color: var(--ink-secondary);
	}

	.pill.due.overdue {
		color: var(--mode-pomodoro);
		background: var(--mode-pomodoro-soft);
	}

	.focus-btn {
		flex: none;
		background: none;
		border: 1px solid var(--border);
		color: var(--brand);
		font-size: 11px;
		cursor: pointer;
	}

	.focus-btn:hover {
		background: var(--brand-soft);
		border-color: transparent;
	}

	@media (max-width: 767px) {
		.meta .pill.energy {
			display: none;
		}
	}
</style>
