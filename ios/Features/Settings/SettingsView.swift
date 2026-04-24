// SettingsView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Settings screen: per-mode timers, theme picker, notifications, and subscription status.
// Changes auto-save on every interaction (no explicit Save button needed).

import SwiftUI
import ComposableArchitecture

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                pomodoroSection
                timeBlockSection
                flowtimeSection
                generalSection
                themeSection
                notificationsSection
                healthSection
                streakSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Settings"))
            .navigationDestination(item: $store.scope(state: \.about, action: \.about)) { aboutStore in
                AboutView(store: aboutStore)
            }
            .onAppear { store.send(.onAppear) }
            .alert(
                String(localized: "Health Access Denied"),
                isPresented: Binding(
                    get: { store.showHealthDeniedAlert },
                    set: { if !$0 { store.send(.healthDeniedAlertDismissed) } }
                )
            ) {
                Button(String(localized: "OK")) { store.send(.healthDeniedAlertDismissed) }
            } message: {
                Text(String(localized: "To log Mindful Minutes, enable Health access for Pepinillo in Settings > Health > Data Access & Devices."))
            }
        }
    }

    // MARK: - Pomodoro Section

    private var pomodoroSection: some View {
        Section {
            Stepper(
                "\(store.pomodoroDurationMinutes) min focus",
                value: Binding(
                    get: { store.pomodoroDurationMinutes },
                    set: { store.send(.pomodoroDurationChanged($0)) }
                ),
                in: 1...120, step: 5
            )
            Stepper(
                "\(store.shortBreakMinutes) min short break",
                value: Binding(
                    get: { store.shortBreakMinutes },
                    set: { store.send(.shortBreakChanged($0)) }
                ),
                in: 1...30, step: 1
            )
            Stepper(
                "\(store.longBreakMinutes) min long break",
                value: Binding(
                    get: { store.longBreakMinutes },
                    set: { store.send(.longBreakChanged($0)) }
                ),
                in: 5...60, step: 5
            )
            Stepper(
                "\(store.pomodorosPerCycle) before long break",
                value: Binding(
                    get: { store.pomodorosPerCycle },
                    set: { store.send(.pomodorosPerCycleChanged($0)) }
                ),
                in: 1...12, step: 1
            )
            Toggle(
                String(localized: "Auto-start breaks"),
                isOn: Binding(
                    get: { store.autoStartBreaks },
                    set: { _ in store.send(.autoStartBreaksToggled) }
                )
            )
            Toggle(
                String(localized: "Auto-start work sessions"),
                isOn: Binding(
                    get: { store.autoStartWork },
                    set: { _ in store.send(.autoStartWorkToggled) }
                )
            )
        } header: {
            Label(String(localized: "Pomodoro"), systemImage: "timer")
                .foregroundStyle(theme.pomodoroColor)
        }
    }

    // MARK: - Time Block Section

    private var timeBlockSection: some View {
        Section {
            Stepper(
                "\(store.blockDurationMinutes) min block",
                value: Binding(
                    get: { store.blockDurationMinutes },
                    set: { store.send(.blockDurationChanged($0)) }
                ),
                in: 5...480, step: 15
            )
            Toggle(
                String(localized: "Midpoint check-in"),
                isOn: Binding(
                    get: { store.blockMidpointCheckIn },
                    set: { _ in store.send(.blockMidpointToggled) }
                )
            )
        } header: {
            Label(String(localized: "Time Block"), systemImage: "rectangle.split.3x1")
                .foregroundStyle(theme.timeBlockColor)
        }
    }

    // MARK: - Flowtime Section

    private var flowtimeSection: some View {
        Section {
            Stepper(
                "\(store.flowtimeMinMinutes) min minimum session",
                value: Binding(
                    get: { store.flowtimeMinMinutes },
                    set: { store.send(.flowtimeMinMinutesChanged($0)) }
                ),
                in: 1...30, step: 1
            )
        } header: {
            Label(String(localized: "Flowtime"), systemImage: "wind")
                .foregroundStyle(theme.flowtimeColor)
        } footer: {
            Text(String(localized: "Minimum focus time before a break is suggested."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            Picker(
                String(localized: "Default mode"),
                selection: Binding(
                    get: { store.defaultMode },
                    set: { store.send(.defaultModeChanged($0)) }
                )
            ) {
                ForEach(FocusMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                }
            }
            Toggle(
                String(localized: "Sound effects"),
                isOn: Binding(
                    get: { store.soundEnabled },
                    set: { _ in store.send(.soundToggled) }
                )
            )
            Toggle(
                String(localized: "Haptic feedback"),
                isOn: Binding(
                    get: { store.hapticEnabled },
                    set: { _ in store.send(.hapticToggled) }
                )
            )
            Toggle(
                String(localized: "Keep screen on during sessions"),
                isOn: Binding(
                    get: { store.keepScreenOn },
                    set: { _ in store.send(.keepScreenOnToggled) }
                )
            )
            Toggle(
                String(localized: "Post-session reflection"),
                isOn: Binding(
                    get: { store.showJournalAfterSession },
                    set: { _ in store.send(.showJournalAfterSessionToggled) }
                )
            )
        } header: {
            Label(String(localized: "General"), systemImage: "gearshape")
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppTheme.all, id: \.name) { t in
                        ThemePreviewCell(
                            theme: t,
                            isSelected: store.themeName == t.name
                        ) {
                            store.send(.themeChanged(t.name))
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Picker(String(localized: "Appearance"), selection: Binding(
                get: { store.appearanceMode },
                set: { store.send(.appearanceModeChanged($0)) }
            )) {
                Text(String(localized: "System")).tag("system")
                Text(String(localized: "Light")).tag("light")
                Text(String(localized: "Dark")).tag("dark")
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(String(localized: "Appearance mode"))
        } header: {
            Label(String(localized: "Theme"), systemImage: "paintpalette")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(
                String(localized: "Daily reminder"),
                isOn: Binding(
                    get: { store.dailyReminderEnabled },
                    set: { _ in store.send(.dailyReminderToggled) }
                )
            )
            if store.dailyReminderEnabled {
                DatePicker(
                    String(localized: "Reminder time"),
                    selection: Binding(
                        get: {
                            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date.now)
                            comps.hour = store.dailyReminderHour
                            comps.minute = store.dailyReminderMinute
                            return Calendar.current.date(from: comps) ?? Date.now
                        },
                        set: { date in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                            store.send(.dailyReminderTimeChanged(
                                hour: comps.hour ?? 9,
                                minute: comps.minute ?? 0
                            ))
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Label(String(localized: "Notifications"), systemImage: "bell")
        }
    }

    // MARK: - Apple Health Section

    private var healthSection: some View {
        Section {
            Toggle(
                String(localized: "Log to Apple Health"),
                isOn: Binding(
                    get: { store.healthLoggingEnabled },
                    set: { _ in store.send(.healthLoggingToggled) }
                )
            )
        } header: {
            Label(String(localized: "Apple Health"), systemImage: "heart.fill")
        } footer: {
            Text(String(localized: "Focus sessions are logged as Mindful Minutes in the Health app."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        Section {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(theme.streakColor)
                    .accessibilityHidden(true)
                Text(String(localized: "Current streak"))
                Spacer()
                Text(String(localized: "\(store.currentStreakDays) days"))
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Current streak, \(store.currentStreakDays) days"))
        } header: {
            Label(String(localized: "Streak"), systemImage: "flame")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            Button {
                store.send(.aboutTapped)
            } label: {
                HStack {
                    Label(String(localized: "About"), systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .accessibilityLabel(String(localized: "About Pepinillo"))
            .accessibilityHint(String(localized: "Opens app information and credits"))
        }
    }
}

// MARK: - Theme Preview Cell

struct ThemePreviewCell: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            VStack(spacing: 8) {
                // Color dots
                HStack(spacing: 5) {
                    ForEach([theme.pomodoroColor, theme.flowtimeColor, theme.timeBlockColor, theme.stopwatchColor], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                    }
                }

                Text(theme.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme\(isSelected ? ", selected" : "")")
    }
}
