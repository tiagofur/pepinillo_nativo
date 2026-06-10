// EnergySuggestion.swift
// Pepinillo — Deep Work Companion for Apple
//
// Pure, testable functions that map the current hour to an EnergyLevel suggestion.
// Based on chronobiology research on cognitive performance across the day.
//
// Mapping:
//   06–10  → deep   (peak executive function, ideal for cognitively demanding work)
//   11–12  → shallow (pre-lunch attention dip, good for communication tasks)
//   13–14  → admin   (post-lunch energy trough, best for filing / organizing)
//   15–17  → deep    (afternoon resurgence, second cognitive peak)
//   18–20  → shallow (evening wind-down, light reviews and email)
//   21–05  → admin   (low-energy night hours)

import Foundation

enum EnergySuggestion {

    /// Returns the suggested `EnergyLevel` for a given hour (0–23, local time).
    static func suggestedLevel(forHour hour: Int) -> EnergyLevel {
        switch hour {
        case 6..<11:  return .deep
        case 11..<13: return .shallow
        case 13..<15: return .admin
        case 15..<18: return .deep
        case 18..<21: return .shallow
        default:      return .admin    // 21–05 (wraps around midnight)
        }
    }

    /// Returns the suggested level for the current local time using a provided `Date`.
    /// Accepts a `Date` parameter so tests can inject a fixed time.
    static func suggestedLevel(for date: Date, calendar: Calendar = .current) -> EnergyLevel {
        let hour = calendar.component(.hour, from: date)
        return suggestedLevel(forHour: hour)
    }

    /// A short, contextual reason string for the suggestion banner.
    static func suggestionReason(forHour hour: Int) -> String {
        switch hour {
        case 6..<11:
            return String(localized: "Morning is your peak window for focused thinking.")
        case 11..<13:
            return String(localized: "Pre-lunch energy dip — great for emails and reviews.")
        case 13..<15:
            return String(localized: "Post-lunch slump is perfect for admin and filing.")
        case 15..<18:
            return String(localized: "Afternoon resurgence — make the most of it.")
        case 18..<21:
            return String(localized: "Wind down with lighter tasks as the day closes.")
        default:
            return String(localized: "Keep it light — save the deep stuff for tomorrow.")
        }
    }
}
