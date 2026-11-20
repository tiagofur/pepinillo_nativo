import { describe, expect, it } from 'vitest';
import { canSync, isEverywhereActive, toGateTier } from '$lib/domain/gates/entitlements';

describe('entitlements', () => {
	it('free user cannot sync', () => {
		expect(isEverywhereActive({ subscriptionTier: 'free', subscriptionExpiresAt: null })).toBe(
			false
		);
		expect(canSync({ id: '1', email: 'a@b.c', name: 'A', subscriptionTier: 'free', emailVerified: true })).toBe(
			false
		);
	});

	it('everywhere_monthly active can sync', () => {
		const user = {
			subscriptionTier: 'everywhere_monthly',
			subscriptionExpiresAt: new Date(Date.now() + 86400000).toISOString()
		};
		expect(isEverywhereActive(user)).toBe(true);
	});

	it('expired everywhere cannot sync', () => {
		const user = {
			subscriptionTier: 'everywhere_annual',
			subscriptionExpiresAt: new Date(Date.now() - 1000).toISOString()
		};
		expect(isEverywhereActive(user)).toBe(false);
	});

	it('toGateTier maps every server tier (table test, #952 judges P1)', () => {
		expect(toGateTier('free')).toBe('free');
		expect(toGateTier('pepinillo_plus')).toBe('pepinillo_plus');
		expect(toGateTier('pepinillo')).toBe('pepinillo_plus'); // legacy alias, defensive
		expect(toGateTier('everywhere_monthly')).toBe('everywhere');
		expect(toGateTier('everywhere_annual')).toBe('everywhere');
		expect(toGateTier('EVERYWHERE_MONTHLY')).toBe('everywhere'); // case-insensitive
		expect(toGateTier('PEPINILLO_PLUS')).toBe('pepinillo_plus');
		expect(toGateTier('')).toBe('free'); // fail closed
		expect(toGateTier('unknown_tier')).toBe('free'); // fail closed
	});
});
