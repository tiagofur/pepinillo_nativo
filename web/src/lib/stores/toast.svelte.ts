/**
 * Toast/Snackbar store — M3-style snackbars with optional action
 * (Mac parity: undo for task completion/deletion, 5 s window).
 */
import { browser } from '$app/environment';

export interface Toast {
	id: number;
	message: string;
	actionLabel?: string;
	/** Called when the action button is pressed; cancels auto-dismiss. */
	onAction?: () => void;
	timeout: ReturnType<typeof setTimeout> | null;
}

class ToastStore {
	toasts = $state<Toast[]>([]);
	private seq = 0;

	show(message: string, opts: { actionLabel?: string; onAction?: () => void; durationMs?: number } = {}): void {
		if (!browser) return;
		const id = ++this.seq;
		const durationMs = opts.durationMs ?? 5000;
		const toast: Toast = {
			id,
			message,
			actionLabel: opts.actionLabel,
			onAction: opts.onAction,
			timeout: setTimeout(() => this.dismiss(id), durationMs)
		};
		this.toasts = [...this.toasts, toast];
		if (this.toasts.length > 3) this.dismiss(this.toasts[0].id);
	}

	action(message: string, actionLabel: string, onAction: () => void, durationMs = 5000): void {
		this.show(message, { actionLabel, onAction, durationMs });
	}

	dismiss(id: number): void {
		const toast = this.toasts.find((t) => t.id === id);
		if (toast?.timeout) clearTimeout(toast.timeout);
		this.toasts = this.toasts.filter((t) => t.id !== id);
	}
}

export const toast = new ToastStore();
