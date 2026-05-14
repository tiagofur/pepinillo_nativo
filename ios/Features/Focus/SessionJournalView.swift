// SessionJournalView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Post-session journal sheet. Shows satisfaction emoji picker and
// a text field for a brief reflection note.

import SwiftUI
import ComposableArchitecture

struct SessionJournalView: View {
    @Bindable var store: StoreOf<SessionJournalFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    ratingSection
                    noteSection
                    actionSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Session Complete")
                .font(.title2.bold())
            Text("\(store.modeName.capitalized) · \(store.durationFormatted)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text("How was your focus?")
                .font(.headline)

            HStack(spacing: 16) {
                ratingButton(id: 1, emoji: "😞", label: String(localized: "Rough"))
                ratingButton(id: 2, emoji: "😐", label: String(localized: "Meh"))
                ratingButton(id: 3, emoji: "🙂", label: String(localized: "Okay"))
                ratingButton(id: 4, emoji: "😊", label: String(localized: "Good"))
                ratingButton(id: 5, emoji: "🔥", label: String(localized: "Great"))
            }
        }
    }

    @ViewBuilder
    private func ratingButton(id: Int, emoji: String, label: String) -> some View {
        let isSelected = store.satisfactionRating == id
        Button {
            store.send(.ratingSelected(id))
        } label: {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 32))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(id) out of 5")
    }

    @ViewBuilder
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick reflection")
                .font(.headline)

            TextField(
                "What went well? What was challenging?",
                text: Binding(
                    get: { store.journalNote },
                    set: { store.send(.noteChanged($0)) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            .modifier(WritingToolsModifier())

            Text("\(store.journalNote.count)/500")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.saveTapped)
            } label: {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)

            Button {
                store.send(.skipTapped)
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Writing Tools (iOS 18.1+)

private struct WritingToolsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.1, macOS 15.0, *) {
            content.writingToolsBehavior(.complete)
        } else {
            content
        }
    }
}
