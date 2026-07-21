// EditProfileView.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftUI view for editing user profile.
// Supports name, birth date, and profile image selection via PhotosPicker.

import SwiftUI
import PhotosUI
import ComposableArchitecture
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - EditProfileView

struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar
                avatarSection

                Text(String(localized: "editprofile.applesignin.explanation", defaultValue: "Apple decides whether to share your name and email during Sign in with Apple. Profile photo is managed manually in Pepinillo, and you can keep using a private relay email or replace it locally here."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "editprofile.name.label", defaultValue: "Name"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(String(localized: "editprofile.name.placeholder", defaultValue: "Your name"), text: $store.name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .accessibilityLabel(String(localized: "editprofile.name.label", defaultValue: "Name"))
                }

                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "editprofile.email.label", defaultValue: "Email"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(String(localized: "auth.field.email", defaultValue: "Email"), text: $store.email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .accessibilityLabel(String(localized: "a11y.auth.field.email.label", defaultValue: "Email address"))
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
                            Text(String(localized: "editprofile.save.button", defaultValue: "Save Changes"))
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading || store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
        }
        .navigationTitle(String(localized: "editprofile.title", defaultValue: "Edit Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "editprofile.cancel.button", defaultValue: "Cancel")) { store.send(.cancelTapped) }
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

                if let selectedImageData = store.selectedImageData,
                   let selectedImage = PlatformImage(data: selectedImageData) {
                    platformImage(selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else if let imageReference = store.imageUrl {
                    ProfileAvatarImageView(imageReference: imageReference) {
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
                        .fill(Color.pepinilloSystemFill.opacity(0.7))
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    ProgressView().tint(.white)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(String(localized: "a11y.editprofile.avatar.label", defaultValue: "Profile photo"))
            .accessibilityHint(store.isUploading
                ? String(localized: "a11y.editprofile.avatar.uploading", defaultValue: "Uploading photo")
                : String(localized: "a11y.editprofile.avatar.hint", defaultValue: "Tap Change Photo to update or remove your profile photo")
            )

            if store.imageUrl != nil || store.selectedImageData != nil {
                Button(String(localized: "editprofile.removephoto.button", defaultValue: "Remove Photo")) {
                    store.send(.removePhoto)
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityLabel(String(localized: "editprofile.removephoto.button", defaultValue: "Remove Photo"))
            }

            // Photo picker
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text(String(localized: "editprofile.changephoto.button", defaultValue: "Change Photo"))
                    .font(.subheadline)
            }
            .disabled(store.isUploading)
            .accessibilityLabel(String(localized: "a11y.editprofile.photopicker.label", defaultValue: "Profile photo"))
            .accessibilityHint(String(localized: "a11y.editprofile.photopicker.hint", defaultValue: "Tap to change or remove your profile photo"))
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

    private func platformImage(_ image: PlatformImage) -> Image {
#if canImport(UIKit)
        Image(uiImage: image)
#elseif canImport(AppKit)
        Image(nsImage: image)
#else
        Image(systemName: "person.circle")
#endif
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif
