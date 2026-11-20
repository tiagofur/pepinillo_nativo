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
	const __PUBLIC_APPLE_CLIENT_ID__: string;
}

export {};

/** Google Identity Services (loaded lazily from accounts.google.com). */
declare const google: {
	accounts: {
		id: {
			initialize(config: {
				client_id: string;
				callback: (response: { credential?: string }) => void;
				nonce?: string;
			}): void;
			renderButton(parent: HTMLElement, options?: Record<string, unknown>): void;
		};
	};
};

/** Sign in with Apple JS (loaded lazily from appleid.cdn-apple.com). */
interface AppleIDAuth {
	init(config: {
		clientId: string;
		scope?: string;
		responseType?: string;
		nonce?: string;
		usePopup?: boolean;
	}): Promise<void>;
	signIn(): Promise<{ authorization: { id_token?: string; code?: string } }>;
}
declare const AppleID: { auth: AppleIDAuth };
