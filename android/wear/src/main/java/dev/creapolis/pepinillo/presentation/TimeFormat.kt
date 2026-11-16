package dev.creapolis.pepinillo.presentation

/**
 * Single compact time notation for every wear surface (#776 Batch C):
 * "1h 45m" / "45m" — same as the phone's dashboard and the iOS shared
 * formatter. Replaces the "1h45m"-without-space variant.
 */
fun formatCompactMinutes(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
