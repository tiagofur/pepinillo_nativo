import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

/**
 * Public env baked at build time. Vite's import.meta.env replacement proved
 * unreliable under rolldown-vite for SvelteKit chunks, so PUBLIC_* vars are
 * baked through explicit __PUBLIC_*__ defines consumed by app code.
 */
type NodeLikeEnv = { process?: { env?: Record<string, string | undefined> } };
const shellEnv = (globalThis as NodeLikeEnv).process?.env ?? {};

const PUBLIC_DEFINE = {
	__PUBLIC_API_BASE_URL__: JSON.stringify(shellEnv.PUBLIC_API_BASE_URL ?? ''),
	__PUBLIC_WS_URL__: JSON.stringify(shellEnv.PUBLIC_WS_URL ?? ''),
	__PUBLIC_GOOGLE_CLIENT_ID__: JSON.stringify(shellEnv.PUBLIC_GOOGLE_CLIENT_ID ?? '')
};

export default defineConfig({
	plugins: [
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
});
