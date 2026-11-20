
import root from '../root.js';
import { set_building, set_prerendering } from '$app/env/internal';
import { set_assets } from '$app/paths/internal/server';
import { set_manifest, set_read_implementation } from '__sveltekit/server';
import { set_private_env, set_public_env } from '../../../../../pepinillo_nativo/web/node_modules/.pnpm/@sveltejs+kit@2.70.2_@sveltejs+vite-plugin-svelte@7.2.0_svelte@5.56.8_vite@8.2.0__svelt_a57f18b526db4ba856e3da8ec9c21795/node_modules/@sveltejs/kit/src/runtime/shared-server.js';
import error from '../shared/error-template.js';

export const options = {
	app_template_contains_nonce: false,
	async: false,
	csp: {"mode":"auto","directives":{"upgrade-insecure-requests":false,"block-all-mixed-content":false},"reportOnly":{"upgrade-insecure-requests":false,"block-all-mixed-content":false}},
	csrf_check_origin: true,
	csrf_trusted_origins: [],
	embedded: false,
	env_public_prefix: 'PUBLIC_',
	env_private_prefix: '',
	hash_routing: false,
	hooks: null, // added lazily, via `get_hooks`
	preload_strategy: "modulepreload",
	root,
	service_worker: false,
	service_worker_options: undefined,
	server_error_boundaries: false,
	templates: {
		app: ({ head, body, assets, nonce, env }) => "<!doctype html>\n<html lang=\"es\">\n\t<head>\n\t\t<meta charset=\"utf-8\" />\n\t\t<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\" />\n\t\t<link rel=\"manifest\" href=\"/manifest.webmanifest\" />\n\t\t<link rel=\"icon\" href=\"/favicon.svg\" type=\"image/svg+xml\" />\n\t\t<link rel=\"apple-touch-icon\" href=\"/icons/apple-touch-icon.png\" />\n\t\t<meta name=\"theme-color\" media=\"(prefers-color-scheme: light)\" content=\"#f5f6f4\" />\n\t\t<meta name=\"theme-color\" media=\"(prefers-color-scheme: dark)\" content=\"#141416\" />\n\t\t<meta name=\"apple-mobile-web-app-capable\" content=\"yes\" />\n\t\t<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"default\" />\n\t\t<meta name=\"apple-mobile-web-app-title\" content=\"Pepinillo\" />\n\t\t<meta name=\"description\" content=\"Pepinillo — planifica, enfócate, celebra. Deep work nativo para tus dispositivos y tu navegador.\" />\n\t\t<script>\n\t\t\t// Apply stored appearance before first paint (no flash of wrong theme).\n\t\t\ttry {\n\t\t\t\tvar a = localStorage.getItem('pepinillo.appearance');\n\t\t\t\tif (a === 'light' || a === 'dark') {\n\t\t\t\t\tdocument.documentElement.setAttribute('data-appearance', a);\n\t\t\t\t}\n\t\t\t\tvar t = localStorage.getItem('pepinillo.theme');\n\t\t\t\tif (t && t !== 'classic') {\n\t\t\t\t\tdocument.documentElement.setAttribute('data-theme', t);\n\t\t\t\t}\n\t\t\t} catch (e) {}\n\t\t</script>\n\t\t" + head + "\n\t</head>\n\t<body data-sveltekit-preload-data=\"hover\">\n\t\t<div style=\"display: contents\">" + body + "</div>\n\t</body>\n</html>\n",
		error
	},
	version_hash: "1ggezrs"
};

export async function get_hooks() {
	let handle;
	let handleFetch;
	let handleError;
	let handleValidationError;
	let init;
	

	let reroute;
	let transport;
	

	return {
		handle,
		handleFetch,
		handleError,
		handleValidationError,
		init,
		reroute,
		transport
	};
}

export { set_assets, set_building, set_manifest, set_prerendering, set_private_env, set_public_env, set_read_implementation };
