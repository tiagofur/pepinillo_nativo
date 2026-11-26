import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { suggestEnergy } from '$lib/domain/tasks/energy';

/**
 * Issue #990 (S1): every platform asserts its hour → energy engine against
 * the same 24-hour fixture versioned in the repo (contracts/fixtures).
 */
describe('shared energy-hours fixture (S1)', () => {
	const fixturePath = resolve(
		fileURLToPath(import.meta.url),
		'../../../../contracts/fixtures/energy-hours-989.json'
	);
	const table = JSON.parse(readFileSync(fixturePath, 'utf8')) as {
		hours: { hour: number; level: 'deep' | 'shallow' | 'admin' }[];
	};

	it('suggestEnergy matches the shared 24-hour table', () => {
		expect(table.hours).toHaveLength(24);
		for (const entry of table.hours) {
			expect(suggestEnergy(entry.hour), `hour ${entry.hour}`).toBe(entry.level);
		}
	});
});
