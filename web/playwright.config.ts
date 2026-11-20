import { defineConfig, devices } from '@playwright/test';

const port = 4173;

export default defineConfig({
	testDir: 'tests/e2e',
	fullyParallel: true,
	forbidOnly: !!process.env.CI,
	retries: process.env.CI ? 1 : 0,
	workers: process.env.CI ? 1 : undefined,
	reporter: process.env.CI ? 'github' : 'list',
	use: {
		baseURL: `http://127.0.0.1:${port}`,
		trace: 'on-first-retry',
		...devices['Desktop Chrome']
	},
	webServer: {
		command: 'pnpm build && pnpm preview --host 127.0.0.1 --port ' + port,
		// e2e exercises UI flows offline — the build guard for PUBLIC_API_BASE_URL
		// (#973) only applies to real production deploys.
		env: { ...process.env, PEP_ALLOW_UNCONFIGURED_BUILD: '1' } as NodeJS.ProcessEnv,
		port,
		reuseExistingServer: !process.env.CI,
		timeout: 120_000
	}
});
