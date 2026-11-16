/**
 * Cronobiología de energía — mirror of iOS EnergySuggestion.swift:
 * 6-10 deep, 11-12 shallow, 13-14 admin, 15-17 deep, 18-20 shallow, 21-5 admin.
 */

import type { TaskEnergy } from '$lib/domain/entities/types';

export function suggestEnergy(hour: number): TaskEnergy {
	if (hour >= 6 && hour < 11) return 'deep';
	if (hour >= 11 && hour < 13) return 'shallow';
	if (hour >= 13 && hour < 15) return 'admin';
	if (hour >= 15 && hour < 18) return 'deep';
	if (hour >= 18 && hour < 21) return 'shallow';
	return 'admin';
}

export const ENERGY_ORDER: readonly TaskEnergy[] = ['deep', 'shallow', 'admin'] as const;
