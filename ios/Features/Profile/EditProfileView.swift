// EditProfileView.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftUI view for editing user profile.
// Supports name, birth date, and profile image selection via PhotosPicker.

import SwiftUI
import PhotosUI
import ComposableArchitecture

// MARK: - EditProfileView

struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                avatarSection

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Your name", text: Binding(
                        get: { store.name },
                        set: { store.send(.nameChanged($0)) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                }

                // Birth date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Birth date")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "Birth date",
                        selection: Binding(
                            get: { store.birthDate ?? Date() },
                            set: { store.send(.birthDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                // Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Save button
                Button {
                    store.send(.saveTapped)
                } label: {
                    Group {
                        if store.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading || store.name.isEmpty)
            }
            .padding(24)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { store.send(.cancelTapped) }
            }
        }
    }

    // MARK: - Avatar Section

    @ViewBuilder
    private var avatarSection: some View {
        VStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 96, height: 96)

                if let imageUrl = store.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }

                if store.isUploading {
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 96, height: 96)
                    ProgressView().tint(.white)
                }
            }

            // Photo picker
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Change Photo")
                    .font(.subheadline)
            }
            .disabled(store.isUploading)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        store.send(.photoSelected(data))
                    }
                }
            }
        }
    }
}
