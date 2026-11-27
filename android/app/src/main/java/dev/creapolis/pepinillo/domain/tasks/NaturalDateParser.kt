package dev.creapolis.pepinillo.domain.tasks

import java.util.Calendar
import java.util.regex.Pattern

/**
 * Issue #994 (S1/S2): a planned date typed at the END of capture text.
 * Pure, on-device, no AI — the same grammar the web
 * (web/src/lib/domain/tasks/natural-date.ts) and iOS (NaturalDateParser in
 * TaskPlanning.swift) resolvers implement from
 * contracts/fixtures/natural-date-cases-994.json. See
 * odd/tasks/994-natural-dates.md §Algoritmo for the shared semantics:
 * only the END of the text is interpreted; morning-phrase guards block the
 * parse («Café de la mañana» keeps its title); numeric dates are always
 * day/month (dd/mm — never month/day) plus dd/mm/yyyy and ISO yyyy-mm-dd;
 * the trailing punctuation mark and the preposition/article right before the
 * date (el, del, para el, on, for, by, na, ...) travel with it; weekday ==
 * today falls to the next week; no match → the input is returned
 * byte-identical with no date; a match that would empty the title is not a
 * match.
 */
object NaturalDateParser {

    /** Original text minus the recognized span, re-trimmed, plus the planned
     *  day as local-midnight epoch millis (null = no date). */
    data class Parsed(val title: String, val plannedDate: Long?)

    private enum class Kind { TODAY, TOMORROW, DAY_AFTER_TOMORROW, WEEKDAY }

    private class DatePhrase(val phrase: String, val kind: Kind, val weekday: Int? = null)

    /** Longest-first so «pasado mañana» wins over «mañana». */
    private val DATE_PHRASES = listOf(
        DatePhrase("pasado mañana", Kind.DAY_AFTER_TOMORROW),
        DatePhrase("pasado manana", Kind.DAY_AFTER_TOMORROW),
        DatePhrase("day after tomorrow", Kind.DAY_AFTER_TOMORROW),
        DatePhrase("depois de amanhã", Kind.DAY_AFTER_TOMORROW),
        DatePhrase("depois de amanha", Kind.DAY_AFTER_TOMORROW),
        DatePhrase("segunda-feira", Kind.WEEKDAY, 1),
        DatePhrase("segunda feira", Kind.WEEKDAY, 1),
        DatePhrase("terça-feira", Kind.WEEKDAY, 2),
        DatePhrase("terca-feira", Kind.WEEKDAY, 2),
        DatePhrase("terça feira", Kind.WEEKDAY, 2),
        DatePhrase("terca feira", Kind.WEEKDAY, 2),
        DatePhrase("quarta-feira", Kind.WEEKDAY, 3),
        DatePhrase("quarta feira", Kind.WEEKDAY, 3),
        DatePhrase("quinta-feira", Kind.WEEKDAY, 4),
        DatePhrase("quinta feira", Kind.WEEKDAY, 4),
        DatePhrase("sexta-feira", Kind.WEEKDAY, 5),
        DatePhrase("sexta feira", Kind.WEEKDAY, 5),
        DatePhrase("miércoles", Kind.WEEKDAY, 3),
        DatePhrase("miercoles", Kind.WEEKDAY, 3),
        DatePhrase("sábado", Kind.WEEKDAY, 6),
        DatePhrase("sabado", Kind.WEEKDAY, 6),
        DatePhrase("amanhã", Kind.TOMORROW),
        DatePhrase("amanha", Kind.TOMORROW),
        DatePhrase("wednesday", Kind.WEEKDAY, 3),
        DatePhrase("tuesday", Kind.WEEKDAY, 2),
        DatePhrase("thursday", Kind.WEEKDAY, 4),
        DatePhrase("saturday", Kind.WEEKDAY, 6),
        DatePhrase("lunes", Kind.WEEKDAY, 1),
        DatePhrase("martes", Kind.WEEKDAY, 2),
        DatePhrase("jueves", Kind.WEEKDAY, 4),
        DatePhrase("viernes", Kind.WEEKDAY, 5),
        DatePhrase("domingo", Kind.WEEKDAY, 7),
        DatePhrase("monday", Kind.WEEKDAY, 1),
        DatePhrase("friday", Kind.WEEKDAY, 5),
        DatePhrase("sunday", Kind.WEEKDAY, 7),
        DatePhrase("segunda", Kind.WEEKDAY, 1),
        DatePhrase("terça", Kind.WEEKDAY, 2),
        DatePhrase("terca", Kind.WEEKDAY, 2),
        DatePhrase("quarta", Kind.WEEKDAY, 3),
        DatePhrase("quinta", Kind.WEEKDAY, 4),
        DatePhrase("sexta", Kind.WEEKDAY, 5),
        DatePhrase("mañana", Kind.TOMORROW),
        DatePhrase("manana", Kind.TOMORROW),
        DatePhrase("tomorrow", Kind.TOMORROW),
        DatePhrase("today", Kind.TODAY),
        DatePhrase("hoy", Kind.TODAY),
        DatePhrase("hoje", Kind.TODAY),
    )

    /** Prepositions/articles that travel with the date. Longest-first. */
    private val STRIP_PHRASES = listOf(
        "el próximo",
        "el proximo",
        "para el",
        "la próxima",
        "la proxima",
        "na próxima",
        "na proxima",
        "próxima",
        "proxima",
        "próximo",
        "proximo",
        "next",
        "del",
        "el",
        "on",
        "for",
        "by",
        "em",
        "na",
        "no",
        "para",
    )

    /** Phrases that mean a time of day, not a future day — they block the parse. */
    private val GUARD_PHRASES = listOf(
        "de la mañana",
        "por la mañana",
        "esta mañana",
        "de manhã",
        "da manhã",
        "pela manhã",
        "esta manhã",
    )

    private val TRAILING_PUNCT = charArrayOf('.', ',', '!', '?')

    /** The exact JS `\s` set (the shared spec's "whitespace") — NOT
     *  Char.isWhitespace, which diverges on U+001C–U+001F (included there,
     *  excluded by JS) and U+FEFF (excluded there, included by JS). Judge B
     *  P1 of this PR: cross-platform S2 equivalence requires this set. */
    private fun isJsWhitespace(c: Char): Boolean = when (c) {
        '\t', '\n', '\u000B', '\u000C', '\r', ' ', '\u00A0', '\u1680',
        '\u2028', '\u2029', '\u202F', '\u205F', '\u3000', '\uFEFF' -> true
        in '\u2000'..'\u200A' -> true
        else -> false
    }

    private fun trimJs(value: String): String =
        value.dropWhile { isJsWhitespace(it) }.dropLastWhile { isJsWhitespace(it) }

    // Explicit JS-\s boundary class and ASCII [0-9] digits (JS \d): without
    // them UNICODE_CHARACTER_CLASS would accept Arabic-Indic digits and
    // platform whitespace would diverge from the web resolver (judge A P2).
    private val ISO_RX = Pattern.compile("""(?:^|[\t\n\u000B\f\r\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF])([0-9]{4})-([0-9]{2})-([0-9]{2})${'$'}""")
    private val DMY_RX = Pattern.compile("""(?:^|[\t\n\u000B\f\r\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF])([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})${'$'}""")
    private val DM_RX = Pattern.compile("""(?:^|[\t\n\u000B\f\r\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF])([0-9]{1,2})/([0-9]{1,2})${'$'}""")

    /** True when [lower] ends with [phrase] at a word boundary (start of text
     *  or after a JS-`\s` whitespace character — never punctuation). */
    private fun endsAtWordBoundary(lower: String, phrase: String): Boolean {
        if (!lower.endsWith(phrase)) return false
        val start = lower.length - phrase.length
        if (start == 0) return true
        return isJsWhitespace(lower[start - 1])
    }

    private fun rstrip(value: String): String = value.trimEnd { isJsWhitespace(it) }

    /** Real-calendar roundtrip: lenient Calendars roll Feb 31 → Mar 3, so a
     *  read-back mismatch means the input was not a real day. */
    private fun localNoon(year: Int, month: Int, day: Int): Calendar? =
        Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }.takeIf {
            it.get(Calendar.YEAR) == year &&
                it.get(Calendar.MONTH) == month - 1 &&
                it.get(Calendar.DAY_OF_MONTH) == day
        }

    private fun startOfToday(nowMillis: Long): Long =
        Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    fun parse(text: String, nowMillis: Long): Parsed {
        val trimmed = trimJs(text)
        if (trimmed.isEmpty()) return Parsed(trimmed, null)

        // The probe drops ONE trailing punctuation mark so «el viernes.»
        // matches; with no match the original text is returned untouched.
        var probe = trimmed
        if (probe.isNotEmpty() && probe.last() in TRAILING_PUNCT) {
            probe = rstrip(probe.dropLast(1))
        }
        if (probe.isEmpty()) return Parsed(trimmed, null)
        val lowerProbe = probe.lowercase()

        val noMatch = Parsed(trimmed, null)

        // Morning-of-day phrases are never dates.
        if (GUARD_PHRASES.any { endsAtWordBoundary(lowerProbe, it) }) return noMatch

        // Empty title after stripping ⇒ not a match (the text IS the date only).
        fun finish(dateMillis: Long?, matchStart: Int): Parsed {
            var title = rstrip(probe.substring(0, matchStart))
            val lowerTitle = title.lowercase()
            for (strip in STRIP_PHRASES) {
                if (endsAtWordBoundary(lowerTitle, strip)) {
                    title = rstrip(title.substring(0, title.length - strip.length))
                    break
                }
            }
            if (title.isEmpty()) return noMatch
            return Parsed(title, dateMillis?.let { TaskPlanning.plannedDay(it) })
        }

        // 1. Numeric dates (unambiguous) — ISO first, then dd/mm/yyyy, then dd/mm.
        ISO_RX.matcher(probe).takeIf { it.find() }?.let { m ->
            val noon = localNoon(m.group(1).toInt(), m.group(2).toInt(), m.group(3).toInt())
                ?: return noMatch
            return finish(noon.timeInMillis, m.start())
        }
        DMY_RX.matcher(probe).takeIf { it.find() }?.let { m ->
            val noon = localNoon(m.group(3).toInt(), m.group(2).toInt(), m.group(1).toInt())
                ?: return noMatch
            return finish(noon.timeInMillis, m.start())
        }
        DM_RX.matcher(probe).takeIf { it.find() }?.let { m ->
            val day = m.group(1).toInt()
            val month = m.group(2).toInt()
            val baseYear = Calendar.getInstance().apply { timeInMillis = nowMillis }.get(Calendar.YEAR)
            // Always the next real calendar day (S1): «29/2» lands on the next
            // leap year, never rolls over to March 1st and never stays in the past.
            val resolved = generateSequence(baseYear) { it + 1 }
                .take(9)
                .map { year -> localNoon(year, month, day)?.timeInMillis }
                .firstOrNull { it != null && it >= startOfToday(nowMillis) }
                ?: return noMatch
            return finish(resolved, m.start())
        }

        // 2. Grammar phrases, longest-first.
        for (candidate in DATE_PHRASES) {
            if (!endsAtWordBoundary(lowerProbe, candidate.phrase)) continue
            // Slice by the ORIGINAL length: lowercasing can expand a code
            // unit («İ» → 2 units) and shifting by the lowered length
            // mangles titles (judge B P1 of PR-c). The phrase itself is NFC
            // Latin — its length is identical in both casings.
            val start = probe.length - candidate.phrase.length
            return finish(resolvePhrase(candidate, nowMillis), start)
        }

        return noMatch
    }

    private fun resolvePhrase(candidate: DatePhrase, nowMillis: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = startOfToday(nowMillis)
            set(Calendar.HOUR_OF_DAY, 12)
        }
        when (candidate.kind) {
            Kind.TODAY -> Unit
            Kind.TOMORROW -> cal.add(Calendar.DAY_OF_MONTH, 1)
            Kind.DAY_AFTER_TOMORROW -> cal.add(Calendar.DAY_OF_MONTH, 2)
            Kind.WEEKDAY -> {
                // ISO weekday (1=Mon..7=Sun); weekday == today → next week (S1).
                val isoToday = when (val dow = cal.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.SUNDAY -> 7
                    else -> dow - 1
                }
                var delta = (candidate.weekday!! - isoToday + 7) % 7
                if (delta == 0) delta = 7
                cal.add(Calendar.DAY_OF_MONTH, delta)
            }
        }
        return cal.timeInMillis
    }
}
