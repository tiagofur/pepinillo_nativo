import { execSync } from 'node:child_process';
import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, type Plugin } from 'vitest/config';

/**
 * Public env baked at build time. Vite's import.meta.env replacement proved
 * unreliable under rolldown-vite for SvelteKit chunks, so PUBLIC_* vars are
 * baked through explicit __PUBLIC_*__ defines consumed by app code.
 */
type NodeLikeEnv = { process?: { env?: Record<string, string | undefined> } };
const shellEnv = (globalThis as NodeLikeEnv).process?.env ?? {};

const publicApiBase = shellEnv.PUBLIC_API_BASE_URL ?? '';

/**
 * Production builds MUST carry the cloud API (#973): an unconfigured prod
 * bundle silently ships Account/auth/sync dead. Local dev stays unconfigured
 * on purpose; e2e and other intentional offline builds opt out explicitly
 * with PEP_ALLOW_UNCONFIGURED_BUILD=1.
 */
function assertProdApiConfigured(mode: string | undefined): void {
	const allowUnconfigured = shellEnv.PEP_ALLOW_UNCONFIGURED_BUILD === '1';
	if (mode === 'production' && !publicApiBase && !allowUnconfigured) {
		throw new Error(
			'PUBLIC_API_BASE_URL is empty — production builds ship Account/auth/sync broken (#973). ' +
				'Set it (https://api.pepinillo.app) or opt out explicitly with PEP_ALLOW_UNCONFIGURED_BUILD=1.'
		);
	}
}

/** Short deploy identity: CI git SHA when available, timestamp otherwise. */
function buildVersion(): string {
	if (shellEnv.PUBLIC_BUILD_VERSION) return shellEnv.PUBLIC_BUILD_VERSION;
	try {
		return execSync('git rev-parse --short HEAD', { stdio: ['ignore', 'pipe', 'ignore'] })
			.toString()
			.trim();
	} catch {
		return `dev-${new Date().toISOString()}`;
	}
}

const BUILD_VERSION = buildVersion();

/** Emit /version.txt so long-lived tabs can detect a new deploy (#974). */
function buildVersionPlugin(): Plugin {
	return {
		name: 'pepinillo-build-version',
		apply: 'build',
		generateBundle() {
			this.emitFile({ type: 'asset', fileName: 'version.txt', source: BUILD_VERSION });
		}
	};
}

const PUBLIC_DEFINE = {
	__PUBLIC_API_BASE_URL__: JSON.stringify(publicApiBase),
	__PUBLIC_WS_URL__: JSON.stringify(shellEnv.PUBLIC_WS_URL ?? ''),
	__PUBLIC_GOOGLE_CLIENT_ID__: JSON.stringify(shellEnv.PUBLIC_GOOGLE_CLIENT_ID ?? ''),
	__PUBLIC_APPLE_CLIENT_ID__: JSON.stringify(shellEnv.PUBLIC_APPLE_CLIENT_ID ?? ''),
	__BUILD_VERSION__: JSON.stringify(BUILD_VERSION)
};

export default defineConfig(({ mode }) => {
	assertProdApiConfigured(mode);
	return {
		plugins: [
			buildVersionPlugin(),
			sveltekit({
				compilerOptions: {
					runes: ({ filename }) =>
						filename.split(/[/\\]/).includes('node_modules') ? undefined : true
				},
				adapter: adapter({
					fallback: 'app.html',
					strict: false
				})
			})
		],
		define: PUBLIC_DEFINE,
		test: {
			include: ['tests/unit/**/*.{test,spec}.ts'],
			environment: 'node',
			globals: false
		}
	};
});
