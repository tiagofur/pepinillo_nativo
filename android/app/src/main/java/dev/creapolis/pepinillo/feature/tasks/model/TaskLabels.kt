package dev.creapolis.pepinillo.feature.tasks.model

import dev.creapolis.pepinillo.R

/**
 * Localized display labels for task-related enums (super-review F3: raw enum names like
 * "High"/"Deep"/"Biweekly" were shown to users in es/pt markets). Maps each enum to its
 * string resource; use from a @Composable via `stringResource(enum.labelRes())`.
 */

fun TaskPriority.labelRes(): Int = when (this) {
    TaskPriority.High -> R.string.priority_high
    TaskPriority.Medium -> R.string.priority_medium
    TaskPriority.Low -> R.string.priority_low
    TaskPriority.None -> R.string.priority_none
}

fun EnergyLevel.labelRes(): Int = when (this) {
    EnergyLevel.Deep -> R.string.energy_deep
    EnergyLevel.Regular -> R.string.energy_regular
    EnergyLevel.Light -> R.string.energy_light
}

fun RecurrenceOption.labelRes(): Int = when (this) {
    RecurrenceOption.None -> R.string.recurrence_none
    RecurrenceOption.Daily -> R.string.recurrence_daily
    RecurrenceOption.Weekdays -> R.string.recurrence_weekdays
    RecurrenceOption.Weekly -> R.string.recurrence_weekly
    RecurrenceOption.Biweekly -> R.string.recurrence_biweekly
    RecurrenceOption.Monthly -> R.string.recurrence_monthly
}
