
// this file is generated — do not edit it


/// <reference types="@sveltejs/kit" />

/**
 * This module provides access to environment variables that are injected _statically_ into your bundle at build time and are limited to _private_ access.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Static environment variables are [loaded by Vite](https://vitejs.dev/guide/env-and-mode.html#env-files) from `.env` files and `process.env` at build time and then statically injected into your bundle at build time, enabling optimisations like dead code elimination.
 * 
 * **_Private_ access:**
 * 
 * - This module cannot be imported into client-side code
 * - This module only includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://svelte.dev/docs/kit/configuration#env) (if configured)
 * 
 * For example, given the following build time environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { ENVIRONMENT, PUBLIC_BASE_URL } from '$env/static/private';
 * 
 * console.log(ENVIRONMENT); // => "production"
 * console.log(PUBLIC_BASE_URL); // => throws error during build
 * ```
 * 
 * The above values will be the same _even if_ different values for `ENVIRONMENT` or `PUBLIC_BASE_URL` are set at runtime, as they are statically replaced in your code with their build time values.
 */
declare module '$env/static/private' {
	export const NODE: string;
	export const ZCODE_BUILTIN_PROVIDER_CONFIG_FILE: string;
	export const INIT_CWD: string;
	export const SHELL: string;
	export const TERM: string;
	export const ZCODE_RG_BINARY: string;
	export const TMPDIR: string;
	export const CLAUDE_PROJECT_DIR: string;
	export const ZCODE_SESSION_ID: string;
	export const ZCODE_CUA_LAUNCHER_PID: string;
	export const ZCODE_PERSONAL_PROVIDER_CONFIG_FILE: string;
	export const MallocNanoZone: string;
	export const ZCODE_UGREP_BINARY: string;
	export const GIT_EDITOR: string;
	export const USER: string;
	export const PYTHONIOENCODING: string;
	export const COMMAND_MODE: string;
	export const ZCODE_PROJECT_DIR: string;
	export const ZCODE_GEN_UI_OUTPUT_ROOT: string;
	export const PNPM_SCRIPT_SRC_DIR: string;
	export const SSH_AUTH_SOCK: string;
	export const __CF_USER_TEXT_ENCODING: string;
	export const ZCODE_PROCESS_LABEL: string;
	export const npm_execpath: string;
	export const PATH: string;
	export const npm_package_json: string;
	export const ZCODE_BUILD_COMMIT_ID: string;
	export const __CFBundleIdentifier: string;
	export const ZCODE_BASE_URL: string;
	export const PWD: string;
	export const npm_command: string;
	export const JAVA_HOME: string;
	export const ZCODE_OFFICIAL_ENDPOINT_TOKEN: string;
	export const npm_lifecycle_event: string;
	export const LANG: string;
	export const npm_package_name: string;
	export const ZAI_OAUTH_ORIGIN: string;
	export const ZCODE_BFS_BINARY: string;
	export const CLAUDE_SESSION_ID: string;
	export const NODE_PATH: string;
	export const XPC_FLAGS: string;
	export const MACH_PORT_RENDEZVOUS_PEER_VALDATION: string;
	export const ZCODE_OFFICIAL_ENDPOINT: string;
	export const npm_config_node_gyp: string;
	export const XPC_SERVICE_NAME: string;
	export const npm_package_version: string;
	export const pnpm_config_verify_deps_before_run: string;
	export const ZCODE_APP_VERSION: string;
	export const HOME: string;
	export const SHLVL: string;
	export const ZCODE_DESKTOP_CONTEXT_PROMPT_ENABLED: string;
	export const PYTHONUTF8: string;
	export const ZCODE_ENV: string;
	export const LOGNAME: string;
	export const npm_lifecycle_script: string;
	export const LC_CTYPE: string;
	export const ZCODE_CUA_BUNDLED_HELPER_APP_PATH: string;
	export const npm_config_user_agent: string;
	export const CLAUDE_CODE_SESSION_ID: string;
	export const ZAI_OAUTH_CLIENT_ID: string;
	export const ZCODE_CLIENT_LANGUAGE: string;
	export const OSLogRateLimit: string;
	export const ZCODE_RUNTIME_ENV: string;
	export const ZAI_BUSINESS_BASE_URL: string;
	export const ZCODE_PREINSTALLED_TOOLS_AVAILABLE: string;
	export const npm_node_execpath: string;
	export const TEST: string;
	export const VITEST: string;
	export const NODE_ENV: string;
	export const PROD: string;
	export const DEV: string;
	export const BASE_URL: string;
	export const MODE: string;
}

/**
 * This module provides access to environment variables that are injected _statically_ into your bundle at build time and are _publicly_ accessible.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Static environment variables are [loaded by Vite](https://vitejs.dev/guide/env-and-mode.html#env-files) from `.env` files and `process.env` at build time and then statically injected into your bundle at build time, enabling optimisations like dead code elimination.
 * 
 * **_Public_ access:**
 * 
 * - This module _can_ be imported into client-side code
 * - **Only** variables that begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) (which defaults to `PUBLIC_`) are included
 * 
 * For example, given the following build time environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { ENVIRONMENT, PUBLIC_BASE_URL } from '$env/static/public';
 * 
 * console.log(ENVIRONMENT); // => throws error during build
 * console.log(PUBLIC_BASE_URL); // => "http://site.com"
 * ```
 * 
 * The above values will be the same _even if_ different values for `ENVIRONMENT` or `PUBLIC_BASE_URL` are set at runtime, as they are statically replaced in your code with their build time values.
 */
declare module '$env/static/public' {
	
}

/**
 * This module provides access to environment variables set _dynamically_ at runtime and that are limited to _private_ access.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Dynamic environment variables are defined by the platform you're running on. For example if you're using [`adapter-node`](https://github.com/sveltejs/kit/tree/main/packages/adapter-node) (or running [`vite preview`](https://svelte.dev/docs/kit/cli)), this is equivalent to `process.env`.
 * 
 * **_Private_ access:**
 * 
 * - This module cannot be imported into client-side code
 * - This module includes variables that _do not_ begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) _and do_ start with [`config.kit.env.privatePrefix`](https://svelte.dev/docs/kit/configuration#env) (if configured)
 * 
 * > [!NOTE] In `dev`, `$env/dynamic` includes environment variables from `.env`. In `prod`, this behavior will depend on your adapter.
 * 
 * > [!NOTE] To get correct types, environment variables referenced in your code should be declared (for example in an `.env` file), even if they don't have a value until the app is deployed:
 * >
 * > ```env
 * > MY_FEATURE_FLAG=
 * > ```
 * >
 * > You can override `.env` values from the command line like so:
 * >
 * > ```sh
 * > MY_FEATURE_FLAG="enabled" npm run dev
 * > ```
 * 
 * For example, given the following runtime environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://site.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { env } from '$env/dynamic/private';
 * 
 * console.log(env.ENVIRONMENT); // => "production"
 * console.log(env.PUBLIC_BASE_URL); // => undefined
 * ```
 */
declare module '$env/dynamic/private' {
	export const env: {
		NODE: string;
		ZCODE_BUILTIN_PROVIDER_CONFIG_FILE: string;
		INIT_CWD: string;
		SHELL: string;
		TERM: string;
		ZCODE_RG_BINARY: string;
		TMPDIR: string;
		CLAUDE_PROJECT_DIR: string;
		ZCODE_SESSION_ID: string;
		ZCODE_CUA_LAUNCHER_PID: string;
		ZCODE_PERSONAL_PROVIDER_CONFIG_FILE: string;
		MallocNanoZone: string;
		ZCODE_UGREP_BINARY: string;
		GIT_EDITOR: string;
		USER: string;
		PYTHONIOENCODING: string;
		COMMAND_MODE: string;
		ZCODE_PROJECT_DIR: string;
		ZCODE_GEN_UI_OUTPUT_ROOT: string;
		PNPM_SCRIPT_SRC_DIR: string;
		SSH_AUTH_SOCK: string;
		__CF_USER_TEXT_ENCODING: string;
		ZCODE_PROCESS_LABEL: string;
		npm_execpath: string;
		PATH: string;
		npm_package_json: string;
		ZCODE_BUILD_COMMIT_ID: string;
		__CFBundleIdentifier: string;
		ZCODE_BASE_URL: string;
		PWD: string;
		npm_command: string;
		JAVA_HOME: string;
		ZCODE_OFFICIAL_ENDPOINT_TOKEN: string;
		npm_lifecycle_event: string;
		LANG: string;
		npm_package_name: string;
		ZAI_OAUTH_ORIGIN: string;
		ZCODE_BFS_BINARY: string;
		CLAUDE_SESSION_ID: string;
		NODE_PATH: string;
		XPC_FLAGS: string;
		MACH_PORT_RENDEZVOUS_PEER_VALDATION: string;
		ZCODE_OFFICIAL_ENDPOINT: string;
		npm_config_node_gyp: string;
		XPC_SERVICE_NAME: string;
		npm_package_version: string;
		pnpm_config_verify_deps_before_run: string;
		ZCODE_APP_VERSION: string;
		HOME: string;
		SHLVL: string;
		ZCODE_DESKTOP_CONTEXT_PROMPT_ENABLED: string;
		PYTHONUTF8: string;
		ZCODE_ENV: string;
		LOGNAME: string;
		npm_lifecycle_script: string;
		LC_CTYPE: string;
		ZCODE_CUA_BUNDLED_HELPER_APP_PATH: string;
		npm_config_user_agent: string;
		CLAUDE_CODE_SESSION_ID: string;
		ZAI_OAUTH_CLIENT_ID: string;
		ZCODE_CLIENT_LANGUAGE: string;
		OSLogRateLimit: string;
		ZCODE_RUNTIME_ENV: string;
		ZAI_BUSINESS_BASE_URL: string;
		ZCODE_PREINSTALLED_TOOLS_AVAILABLE: string;
		npm_node_execpath: string;
		TEST: string;
		VITEST: string;
		NODE_ENV: string;
		PROD: string;
		DEV: string;
		BASE_URL: string;
		MODE: string;
		[key: `PUBLIC_${string}`]: undefined;
		[key: `${string}`]: string | undefined;
	}
}

/**
 * This module provides access to environment variables set _dynamically_ at runtime and that are _publicly_ accessible.
 * 
 * |         | Runtime                                                                    | Build time                                                               |
 * | ------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
 * | Private | [`$env/dynamic/private`](https://svelte.dev/docs/kit/$env-dynamic-private) | [`$env/static/private`](https://svelte.dev/docs/kit/$env-static-private) |
 * | Public  | [`$env/dynamic/public`](https://svelte.dev/docs/kit/$env-dynamic-public)   | [`$env/static/public`](https://svelte.dev/docs/kit/$env-static-public)   |
 * 
 * Dynamic environment variables are defined by the platform you're running on. For example if you're using [`adapter-node`](https://github.com/sveltejs/kit/tree/main/packages/adapter-node) (or running [`vite preview`](https://svelte.dev/docs/kit/cli)), this is equivalent to `process.env`.
 * 
 * **_Public_ access:**
 * 
 * - This module _can_ be imported into client-side code
 * - **Only** variables that begin with [`config.kit.env.publicPrefix`](https://svelte.dev/docs/kit/configuration#env) (which defaults to `PUBLIC_`) are included
 * 
 * > [!NOTE] In `dev`, `$env/dynamic` includes environment variables from `.env`. In `prod`, this behavior will depend on your adapter.
 * 
 * > [!NOTE] To get correct types, environment variables referenced in your code should be declared (for example in an `.env` file), even if they don't have a value until the app is deployed:
 * >
 * > ```env
 * > MY_FEATURE_FLAG=
 * > ```
 * >
 * > You can override `.env` values from the command line like so:
 * >
 * > ```sh
 * > MY_FEATURE_FLAG="enabled" npm run dev
 * > ```
 * 
 * For example, given the following runtime environment:
 * 
 * ```env
 * ENVIRONMENT=production
 * PUBLIC_BASE_URL=http://example.com
 * ```
 * 
 * With the default `publicPrefix` and `privatePrefix`:
 * 
 * ```ts
 * import { env } from '$env/dynamic/public';
 * console.log(env.ENVIRONMENT); // => undefined, not public
 * console.log(env.PUBLIC_BASE_URL); // => "http://example.com"
 * ```
 * 
 * ```
 * 
 * ```
 */
declare module '$env/dynamic/public' {
	export const env: {
		[key: `PUBLIC_${string}`]: string | undefined;
	}
}
