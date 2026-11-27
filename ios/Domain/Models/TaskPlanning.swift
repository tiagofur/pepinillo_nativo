// TaskPlanning.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single «Hoy» rule shared by every Apple surface (issue #991 S2/S3): the
// Plan lists, widgets, watch list, complications, Siri and the Mac Today
// panel all resolve buckets here. The rule is asserted against
// contracts/fixtures/task-planning-cases-991.json — a shared case table that
// the Android and web suites decode too.

import Foundation

/// Where an active task lives in Plan. `.completed` exists for fixture
/// completeness; most callers filter completed tasks before bucketing.
public enum TaskPlanningBucket: Equatable, Sendable {
    /// «Hoy» — planned today or earlier (S6 keeps past plans visible as
    /// `postponed`), or due today or overdue.
    case today(postponed: Bool)
    /// «Próximas» — first planned or due day is strictly in the future.
    case upcoming
    /// «Bandeja» — no planned date and no due date.
    case inbox
    case completed
}

/// Pure resolver for the unified «Hoy» rule (issue #991 S2).
///
/// `plannedDate` is a local calendar day stored as the start of that day.
/// `scheduledForToday` is the legacy pre-#991 boolean that still travels on
/// the wire (S9) and still exists in older stores: it acts as a sync shim
/// only where the new semantics don't speak (no planned date, or a future
/// one). A past planned date always keeps its S6 postponement.
public enum TaskPlanning {

    /// The bucket a task belongs to right now.
    public static func bucket(
        plannedDate: Date?,
        dueDate: Date?,
        scheduledForToday: Bool = false,
        isCompleted: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskPlanningBucket {
        if isCompleted { return .completed }

        // Legacy shim: an older cohort's "in today's list" flag keeps the
        // task in «Hoy» until a written planned date (past plans keep the
        // S6 badge) or the physical backfill replaces it.
        let plannedIsMissingOrFuture = plannedDate.map { isFutureDay($0, now: now, calendar: calendar) } ?? true
        if scheduledForToday, plannedIsMissingOrFuture {
            return .today(postponed: false)
        }

        if let plannedDate, isOnOrBefore(plannedDate, now, calendar: calendar) {
            return .today(postponed: !calendar.isDate(plannedDate, inSameDayAs: now))
        }
        if let dueDate, isOnOrBefore(dueDate, now, calendar: calendar) {
            return .today(postponed: false)
        }
        return (plannedDate != nil || dueDate != nil) ? .upcoming : .inbox
    }

    /// Canonical storage form for a planned date: start of the local day.
    /// Recurrence (S8) and every write path normalize through this.
    public static func plannedDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Start of tomorrow in the local calendar (S5 quick add from «Próximas»).
    public static func tomorrow(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }

    /// The coming Saturday — «Este fin de semana» (S4). If today is Saturday or
    /// Sunday the plan lands on NEXT weekend's Saturday (the current one is over).
    public static func upcomingWeekend(from date: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)  // 1 = Sunday … 7 = Saturday
        let daysUntilSaturday = (7 - weekday) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)!
    }

    /// Derived value of the legacy `scheduledForToday` boolean for a written
    /// planned date (S9 compat: old installs and pre-PR-C surfaces read the
    /// flag). True while the plan is today or already past — a postponed task
    /// keeps the flag, so legacy «Hoy» surfaces keep showing it (S6).
    public static func legacyFlag(plannedDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let plannedDate else { return false }
        return isOnOrBefore(plannedDate, now, calendar: calendar)
    }

    // MARK: - Day comparisons

    static func isOnOrBefore(_ date: Date, _ reference: Date, calendar: Calendar) -> Bool {
        calendar.compare(date, to: reference, toGranularity: .day) != .orderedDescending
    }

    static func isFutureDay(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.compare(date, to: now, toGranularity: .day) == .orderedDescending
    }
}

/// Issue #994 (S1/S2): a planned date typed at the END of capture text.
/// Pure, on-device, no AI — the same grammar the web
/// (`web/src/lib/domain/tasks/natural-date.ts`) and Android
/// (`NaturalDateParser.kt`) resolvers implement from
/// contracts/fixtures/natural-date-cases-994.json. See
/// odd/tasks/994-natural-dates.md §Algoritmo for the shared semantics:
/// only the END of the text is interpreted; morning-phrase guards block the
/// parse («Café de la mañana» keeps its title); numeric dates are always
/// day/month (dd/mm — never month/day) with real-calendar roundtrip
/// validity; the trailing punctuation mark and the preposition/article right
/// before the date (el, del, para el, on, for, by, na, ...) travel with it;
/// weekday == today falls to the next week; no match → the input is returned
/// byte-identical with no date; a match that would empty the title is not a
/// match.
public enum NaturalDateParser {

    public struct Parsed: Equatable, Sendable {
        /// Original text minus the recognized span, re-trimmed.
        public let title: String
        /// Start of the resolved local day, or nil.
        public let plannedDate: Date?

        init(title: String, plannedDate: Date?) {
            self.title = title
            self.plannedDate = plannedDate
        }
    }

    private enum PhraseKind {
        case today
        case tomorrow
        case dayAfterTomorrow
        case weekday(Int)
    }

    private struct DatePhrase {
        let phrase: String
        let kind: PhraseKind
    }

    /// Every parent phrase precedes its suffixes («pasado mañana» before
    /// «mañana», «segunda-feira» before «segunda») so the longer reading
    /// wins; exact-suffix matching makes the rest of the order irrelevant.
    /// Keep this order aligned with the Android/web tables.
    private static let phrases: [DatePhrase] = [
        DatePhrase(phrase: "pasado mañana", kind: .dayAfterTomorrow),
        DatePhrase(phrase: "pasado manana", kind: .dayAfterTomorrow),
        DatePhrase(phrase: "day after tomorrow", kind: .dayAfterTomorrow),
        DatePhrase(phrase: "depois de amanhã", kind: .dayAfterTomorrow),
        DatePhrase(phrase: "depois de amanha", kind: .dayAfterTomorrow),
        DatePhrase(phrase: "segunda-feira", kind: .weekday(1)),
        DatePhrase(phrase: "segunda feira", kind: .weekday(1)),
        DatePhrase(phrase: "terça-feira", kind: .weekday(2)),
        DatePhrase(phrase: "terca-feira", kind: .weekday(2)),
        DatePhrase(phrase: "terça feira", kind: .weekday(2)),
        DatePhrase(phrase: "terca feira", kind: .weekday(2)),
        DatePhrase(phrase: "quarta-feira", kind: .weekday(3)),
        DatePhrase(phrase: "quarta feira", kind: .weekday(3)),
        DatePhrase(phrase: "quinta-feira", kind: .weekday(4)),
        DatePhrase(phrase: "quinta feira", kind: .weekday(4)),
        DatePhrase(phrase: "sexta-feira", kind: .weekday(5)),
        DatePhrase(phrase: "sexta feira", kind: .weekday(5)),
        DatePhrase(phrase: "miércoles", kind: .weekday(3)),
        DatePhrase(phrase: "miercoles", kind: .weekday(3)),
        DatePhrase(phrase: "sábado", kind: .weekday(6)),
        DatePhrase(phrase: "sabado", kind: .weekday(6)),
        DatePhrase(phrase: "amanhã", kind: .tomorrow),
        DatePhrase(phrase: "amanha", kind: .tomorrow),
        DatePhrase(phrase: "wednesday", kind: .weekday(3)),
        DatePhrase(phrase: "tuesday", kind: .weekday(2)),
        DatePhrase(phrase: "thursday", kind: .weekday(4)),
        DatePhrase(phrase: "saturday", kind: .weekday(6)),
        DatePhrase(phrase: "lunes", kind: .weekday(1)),
        DatePhrase(phrase: "martes", kind: .weekday(2)),
        DatePhrase(phrase: "jueves", kind: .weekday(4)),
        DatePhrase(phrase: "viernes", kind: .weekday(5)),
        DatePhrase(phrase: "domingo", kind: .weekday(7)),
        DatePhrase(phrase: "monday", kind: .weekday(1)),
        DatePhrase(phrase: "friday", kind: .weekday(5)),
        DatePhrase(phrase: "sunday", kind: .weekday(7)),
        DatePhrase(phrase: "segunda", kind: .weekday(1)),
        DatePhrase(phrase: "terça", kind: .weekday(2)),
        DatePhrase(phrase: "terca", kind: .weekday(2)),
        DatePhrase(phrase: "quarta", kind: .weekday(3)),
        DatePhrase(phrase: "quinta", kind: .weekday(4)),
        DatePhrase(phrase: "sexta", kind: .weekday(5)),
        DatePhrase(phrase: "mañana", kind: .tomorrow),
        DatePhrase(phrase: "manana", kind: .tomorrow),
        DatePhrase(phrase: "tomorrow", kind: .tomorrow),
        DatePhrase(phrase: "today", kind: .today),
        DatePhrase(phrase: "hoy", kind: .today),
        DatePhrase(phrase: "hoje", kind: .today)
    ]

    /// Prepositions/articles that travel with the date. Longest-first, one
    /// phrase per match, single pass — compounds are units, not loops.
    private static let stripPhrases = [
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
        "para"
    ]

    /// Phrases that mean a time of day, not a future day — they block the parse.
    private static let guardPhrases = [
        "de la mañana",
        "por la mañana",
        "esta mañana",
        "de manhã",
        "da manhã",
        "pela manhã",
        "esta manhã"
    ]

    private static let trailingPunctuation: Set<Character> = [".", ",", "!", "?"]

    /// The exact JS `\s` set (the shared spec's "whitespace") tested on
    /// Unicode scalars — NOT Character.isWhitespace/Character checks, which
    /// diverge on U+001C–U+001F (included there, excluded by JS), U+FEFF
    /// (excluded there, included by JS) and CRLF (one grapheme, two units).
    /// Judge B P1s of PR-b and PR-c: cross-platform S2 equivalence requires
    /// this exact set on this exact unit.
    fileprivate static func isJsWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x20, 0xA0, 0x1680,
             0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    private static let isoRegex = try! NSRegularExpression(pattern: "(?:^|[\\t\\n\\u000B\\f\\r\\u0020\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF])([0-9]{4})-([0-9]{2})-([0-9]{2})$")
    private static let dayMonthYearRegex = try! NSRegularExpression(pattern: "(?:^|[\\t\\n\\u000B\\f\\r\\u0020\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF])([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$")
    private static let dayMonthRegex = try! NSRegularExpression(pattern: "(?:^|[\\t\\n\\u000B\\f\\r\\u0020\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000\\uFEFF])([0-9]{1,2})/([0-9]{1,2})$")

    public static func parse(
        _ text: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Parsed {
        let trimmed = text.trimJsWhitespace()
        if trimmed.isEmpty { return Parsed(title: trimmed, plannedDate: nil) }

        // The probe drops ONE trailing punctuation mark so «el viernes.»
        // matches; with no match the original text is returned untouched.
        var probe = trimmed
        if let last = probe.last, trailingPunctuation.contains(last) {
            probe = String(probe.dropLast()).rstripWhitespace()
        }
        if probe.isEmpty { return Parsed(title: trimmed, plannedDate: nil) }
        let lowerProbe = probe.lowercased()

        let noMatch = Parsed(title: trimmed, plannedDate: nil)

        // Morning-of-day phrases are never dates.
        if guardPhrases.contains(where: { endsAtWordBoundary(lowerProbe, $0) }) {
            return noMatch
        }

        // Empty title after stripping ⇒ not a match (the text IS the date only).
        func finish(_ day: Date?, droppingSuffixOf phrase: String) -> Parsed {
            var title = String(probe.dropLast(phrase.count)).rstripWhitespace()
            let lowerTitle = title.lowercased()
            for strip in stripPhrases where endsAtWordBoundary(lowerTitle, strip) {
                title = String(title.dropLast(strip.count)).rstripWhitespace()
                break
            }
            if title.isEmpty { return noMatch }
            return Parsed(
                title: title,
                plannedDate: day.map { TaskPlanning.plannedDay($0, calendar: calendar) }
            )
        }

        // 1. Numeric dates (unambiguous) — ISO first, then dd/mm/yyyy, then dd/mm.
        let probeRange = NSRange(probe.startIndex..., in: probe)
        func group(_ match: NSTextCheckingResult, _ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: probe) else { return "" }
            return String(probe[range])
        }
        if let match = isoRegex.firstMatch(in: probe, range: probeRange) {
            guard let day = realCalendarDay(
                Int(group(match, 1)) ?? -1, Int(group(match, 2)) ?? -1, Int(group(match, 3)) ?? -1,
                calendar
            ) else { return noMatch }
            return finish(day, droppingSuffixOf: String(probe[Range(match.range, in: probe)!]))
        }
        if let match = dayMonthYearRegex.firstMatch(in: probe, range: probeRange) {
            guard let day = realCalendarDay(
                Int(group(match, 3)) ?? -1, Int(group(match, 2)) ?? -1, Int(group(match, 1)) ?? -1,
                calendar
            ) else { return noMatch }
            return finish(day, droppingSuffixOf: String(probe[Range(match.range, in: probe)!]))
        }
        if let match = dayMonthRegex.firstMatch(in: probe, range: probeRange) {
            let dayOfMonth = Int(group(match, 1)) ?? -1
            let month = Int(group(match, 2)) ?? -1
            let baseYear = calendar.component(.year, from: now)
            // Always the next real calendar day (S1): «29/2» lands on the next
            // leap year, never rolls over to March 1st and never stays in the past.
            var resolved: Date?
            for year in baseYear...(baseYear + 8) {
                guard let candidate = realCalendarDay(year, month, dayOfMonth, calendar),
                      calendar.compare(candidate, to: now, toGranularity: .day) != .orderedAscending
                else { continue }
                resolved = candidate
                break
            }
            guard let resolved else { return noMatch }
            return finish(resolved, droppingSuffixOf: String(probe[Range(match.range, in: probe)!]))
        }

        // 2. Grammar phrases.
        for candidate in phrases where endsAtWordBoundary(lowerProbe, candidate.phrase) {
            return finish(resolvePhrase(candidate.kind, now: now, calendar: calendar),
                          droppingSuffixOf: candidate.phrase)
        }

        return noMatch
    }

    // MARK: - Shared grammar helpers

    /// Word boundary = start of text or a JS-`\s` whitespace character,
    /// NEVER punctuation (regex \b would accept «compra:viernes»).
    /// Comparisons run on Unicode SCALARS with exact equality: Swift Strings
    /// are grapheme clusters with canonical equivalence, so `"\r\n"` is one
    /// Character (JS sees two code units, the last one whitespace) and
    /// decomposed NFD text would canonically match its NFC phrase — both
    /// diverge from the web reference (judge B P1s, #994 PR-c).
    private static func endsAtWordBoundary(_ lower: String, _ phrase: String) -> Bool {
        let lowerScalars = Array(lower.unicodeScalars)
        let phraseScalars = Array(phrase.unicodeScalars)
        let start = lowerScalars.count - phraseScalars.count
        guard start >= 0 else { return false }
        for offset in 0..<phraseScalars.count
        where lowerScalars[start + offset] != phraseScalars[offset] {
            return false
        }
        if start == 0 { return true }
        return isJsWhitespace(lowerScalars[start - 1])
    }

    /// Real-calendar roundtrip: constructing a nonexistent day (Feb 31) must
    /// fail, not roll over.
    private static func realCalendarDay(
        _ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else { return nil }
        let readBack = calendar.dateComponents([.year, .month, .day], from: date)
        guard readBack.year == year, readBack.month == month, readBack.day == day else { return nil }
        return date
    }

    private static func resolvePhrase(
        _ kind: PhraseKind, now: Date, calendar: Calendar
    ) -> Date {
        let day = calendar.startOfDay(for: now)
        switch kind {
        case .today:
            return day
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: day)!
        case .dayAfterTomorrow:
            return calendar.date(byAdding: .day, value: 2, to: day)!
        case .weekday(let isoWeekday):
            // ISO weekday (1=Mon..7=Sun); weekday == today → next week (S1).
            let rawWeekday = calendar.component(.weekday, from: day)  // 1 = Sunday … 7 = Saturday
            let isoToday = rawWeekday == 1 ? 7 : rawWeekday - 1
            var delta = (isoWeekday - isoToday + 7) % 7
            if delta == 0 { delta = 7 }
            return calendar.date(byAdding: .day, value: delta, to: day)!
        }
    }
}

private extension String {
    /// Trailing JS-`\s` whitespace only, compared on Unicode scalars (a
    /// trailing "\r\n" is one Character but two JS units — both strip).
    func rstripWhitespace() -> String {
        var scalars = Array(unicodeScalars)
        while let last = scalars.last, NaturalDateParser.isJsWhitespace(last) {
            scalars.removeLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }

    /// Trim of the exact JS `\s` set (JS `String.prototype.trim` semantics)
    /// on Unicode scalars — not `.whitespacesAndNewlines` (diverges on
    /// U+001C–U+001F / U+FEFF / CRLF clusters).
    func trimJsWhitespace() -> String {
        var scalars = Array(unicodeScalars)
        while let first = scalars.first, NaturalDateParser.isJsWhitespace(first) {
            scalars.removeFirst()
        }
        while let last = scalars.last, NaturalDateParser.isJsWhitespace(last) {
            scalars.removeLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
