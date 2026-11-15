/* Entitlements — mirrors iOS isProUser: Pepinillo+ lifetime includes local
   premium; Everywhere includes everything in Plus. Server tier (GET
   /users/me) is the source of truth; unknown tiers fail closed (free). */

const PRO_TIERS = new Set([
  "pepinillo_plus",
  "everywhere_monthly",
  "everywhere_annual",
  // Legacy aliases the retired web client accepted.
  "everywhere_plus",
  "everywhere",
]);

export function isProTier(tier: string | null | undefined): boolean {
  if (!tier) return false;
  const normalized = tier.toLowerCase();
  if (PRO_TIERS.has(normalized)) return true;
  return normalized.startsWith("everywhere");
}
