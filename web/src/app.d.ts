// See https://svelte.dev/docs/kit/types#app.d.ts
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}

	/** Baked at build time via `define` in vite.config.ts (public env). */
	const __PUBLIC_API_BASE_URL__: string;
	const __PUBLIC_WS_URL__: string;
	const __PUBLIC_GOOGLE_CLIENT_ID__: string;
}

export {};
