import { expect, type Page, test } from '@playwright/test';

async function openApp(page: Page, path = '/focus/') {
	await page.goto(path);
	await page.waitForLoadState('networkidle');
	// Dismiss first-run onboarding if shown
	const dialog = page.getByRole('dialog');
	if (await dialog.isVisible().catch(() => false)) {
		await page.getByRole('button', { name: /skip|omitir|pular/i }).click();
		await expect(dialog).toBeHidden();
	}
}

test.describe('W1 Free companion smoke', () => {
	test('shell tabs navigate Focus Plan Dashboard Account', async ({ page }) => {
		await openApp(page, '/focus/');
		await expect(page.getByRole('heading', { name: /focus|foco/i })).toBeVisible();

		await page.getByRole('navigation', { name: 'Primary' }).getByRole('link', { name: /plan/i }).click();
		await expect(page.getByRole('heading', { name: /plan/i })).toBeVisible();

		await page
			.getByRole('navigation', { name: 'Primary' })
			.getByRole('link', { name: /dashboard|panel|painel/i })
			.click();
		await expect(page.getByRole('heading', { name: /dashboard|panel|painel/i })).toBeVisible();

		await page
			.getByRole('navigation', { name: 'Primary' })
			.getByRole('link', { name: /account|cuenta|conta/i })
			.click();
		await expect(page.getByRole('heading', { name: /account|cuenta|conta/i })).toBeVisible();
	});

	test('start and pause a Pomodoro session', async ({ page }) => {
		await openApp(page, '/focus/');

		await page.getByRole('button', { name: /pomodoro/i }).first().click();
		await page.getByRole('button', { name: /start|iniciar|começar/i }).click();
		await expect(page.getByText(/in session|en sesión|em sessão/i)).toBeVisible();

		await page.getByRole('button', { name: /pause|pausar/i }).click();
		await expect(page.getByText(/paused|pausado/i)).toBeVisible();
	});

	test('enforces Free active task cap of 3', async ({ page }) => {
		await openApp(page, '/plan/');

		const input = page.getByPlaceholder(/what needs focus|en qué|no que focar/i);
		const add = page.locator('form.quick-add').getByRole('button', { name: /add task|agregar|adicionar/i });

		for (let i = 1; i <= 3; i++) {
			await input.fill(`Task ${i}`);
			await add.click();
			await expect(page.getByRole('heading', { name: `Task ${i}` })).toBeVisible();
		}

		await input.fill('Task overflow');
		await add.click();
		await expect(page.getByText(/free allows up to 3|free permite|até 3/i)).toBeVisible();
	});
});
