// AuthField.swift
// Pepinillo — Deep Work Companion for Apple

import SwiftUI

struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var trailingIcon: String? = nil
    var onTrailingIconTap: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isFocused ? .primary : .secondary)
                .frame(width: 24)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.body)
            .autocorrectionDisabled(true)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .focused($isFocused)

            if let trailingIcon {
                Button {
                    onTrailingIconTap?()
                } label: {
                    Image(systemName: trailingIcon)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SpacingTokens.md)
        .frame(minHeight: 56)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous)
                    .fill(.ultraThinMaterial)

                if isFocused {
                    RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous)
                        .stroke(.primary.opacity(0.12), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: GlassCornerRadius.control, style: .continuous)
                        .stroke(.secondary.opacity(0.1), lineWidth: 1)
                }
            }
        )
    }
}
