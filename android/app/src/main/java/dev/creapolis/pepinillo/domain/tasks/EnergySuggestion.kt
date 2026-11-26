package dev.creapolis.pepinillo.domain.tasks

import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel

/**
 * Issue #990 (S1): hour → energy engine. The table is mirrored from
 * contracts/fixtures/energy-hours-989.json (the single source of truth —
 * this suite and the web/iOS suites all assert against it). Canonical
 * levels map onto Android's UI labels: deep→Deep, shallow→Light,
 * admin→Regular.
 *
 * 06–10 deep · 11–12 shallow · 13–14 admin · 15–17 deep · 18–20 shallow · 21–05 admin
 */
object EnergySuggestion {
    fun suggestedLevel(hour: Int): EnergyLevel = when (hour) {
        in 6..10 -> EnergyLevel.Deep
        in 11..12 -> EnergyLevel.Light
        in 13..14 -> EnergyLevel.Regular
        in 15..17 -> EnergyLevel.Deep
        in 18..20 -> EnergyLevel.Light
        else -> EnergyLevel.Regular
    }
}
