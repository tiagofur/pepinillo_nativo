/** Everywhere subscription tiers granted by backend `subscriptionTier`. */
const EVERYWHERE_TIERS = new Set([
	'everywhere_monthly',
	'everywhere_annual',
	'everywhere_plus',
	'everywhere'
]);

export type RemoteUser = {
	id: string;
	email: string;
	name: string;
	subscriptionTier: string;
	subscriptionExpiresAt?: string | null;
	emailVerified: boolean;
	imageUrl?: string | null;
};

export function isEverywhereActive(
	user: Pick<RemoteUser, 'subscriptionTier' | 'subscriptionExpiresAt'> | null | undefined,
	now: Date = new Date()
): boolean {
	if (!user) return false;
	const tier = (user.subscriptionTier || 'free').toLowerCase();
	if (!EVERYWHERE_TIERS.has(tier) && !tier.startsWith('everywhere')) {
		return false;
	}
	if (user.subscriptionExpiresAt) {
		const exp = new Date(user.subscriptionExpiresAt);
		if (!Number.isNaN(exp.getTime()) && exp.getTime() <= now.getTime()) {
			return false;
		}
	}
	return true;
}

export function canSync(user: RemoteUser | null | undefined, now?: Date): boolean {
	return isEverywhereActive(user, now);
}
