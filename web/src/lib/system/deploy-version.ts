/**
 * Deploy freshness watch (#974) — a long-lived SPA tab never learns a new
 * deploy landed, and its lazily-imported route chunks are deleted by the
 * next `rsync --delete` (stale tab: URL changes, screen doesn't). The build
 * bakes its identity (__BUILD_VERSION__) and emits the same value as
 * /version.txt; this watch polls it and fires `onNewDeploy` ONCE so the
 * shell can offer a reload toast. Poll cadence + visibilitychange covers
 * the PWA case (tab asleep in the background for hours).
 */
import { browser } from '$app/environment';

const POLL_INTERVAL_MS = 5 * 60_000;

export function bootBuildVersion(): string {
	return __BUILD_VERSION__;
}

export async function fetchDeployedVersion(): Promise<string | null> {
	try {
		const res = await fetch(`/version.txt?nocache=${Date.now()}`, { cache: 'no-cache' });
		if (!res.ok) return null;
		const version = (await res.text()).trim();
		return version || null;
	} catch {
		return null;
	}
}

/** True when the server is running a different (newer) deploy than this tab. */
export function isDeployedVersionStale(boot: string, deployed: string | null): boolean {
	return Boolean(deployed && boot && deployed !== boot);
}

/**
 * Starts the watch; returns a stop function. No-op outside the browser and
 * in dev (dev has no version.txt and hot-reloads already pick up edits —
 * same contract as the service worker registration).
 */
export function startDeployWatch(onNewDeploy: () => void): () => void {
	if (!browser || import.meta.env.DEV) return () => {};
	const boot = bootBuildVersion();
	let stopped = false;
	let fired = false;

	const check = async (): Promise<void> => {
		if (stopped || fired) return;
		const deployed = await fetchDeployedVersion();
		if (isDeployedVersionStale(boot, deployed)) {
			fired = true;
			onNewDeploy();
		}
	};

	const onVisibility = (): void => {
		if (document.visibilityState === 'visible') void check();
	};

	document.addEventListener('visibilitychange', onVisibility);
	const timer = setInterval(() => void check(), POLL_INTERVAL_MS);

	return () => {
		stopped = true;
		clearInterval(timer);
		document.removeEventListener('visibilitychange', onVisibility);
	};
}
