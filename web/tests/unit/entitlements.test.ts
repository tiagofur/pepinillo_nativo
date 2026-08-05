import { describe, expect, it } from 'vitest';
import { canSync, isEverywhereActive } from '$lib/domain/gates/entitlements';

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
});
