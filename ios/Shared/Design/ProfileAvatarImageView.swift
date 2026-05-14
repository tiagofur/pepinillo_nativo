// ProfileAvatarImageView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared avatar renderer that supports three sources:
// - remote URLs
// - local file URLs
// - inline data URLs for Apple-local profile photos

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfileAvatarImageView<Placeholder: View>: View {
    let imageReference: String?
    let placeholder: () -> Placeholder

    init(imageReference: String?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageReference = imageReference
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = resolvedInlineImage {
            platformImage(image)
                .resizable()
                .scaledToFill()
        } else if let remoteURL = remoteURL {
            AsyncImage(url: remoteURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder()
            }
        } else {
            placeholder()
        }
    }

    private func platformImage(_ image: PlatformImage) -> Image {
#if canImport(UIKit)
        Image(uiImage: image)
#elseif canImport(AppKit)
        Image(nsImage: image)
#else
        Image(systemName: "person.crop.circle")
#endif
    }

    private var resolvedInlineImage: PlatformImage? {
#if canImport(UIKit) || canImport(AppKit)
        guard let imageReference, !imageReference.isEmpty else {
            return nil
        }

        if imageReference.hasPrefix("data:image"),
           let commaIndex = imageReference.firstIndex(of: ",") {
            let base64 = String(imageReference[imageReference.index(after: commaIndex)...])
            guard let data = Data(base64Encoded: base64) else {
                return nil
            }
            return PlatformImage(data: data)
        }

        guard let url = URL(string: imageReference), url.isFileURL else {
            return nil
        }
        return PlatformImage(contentsOfFile: url.path)
#else
        return nil
#endif
    }

    private var remoteURL: URL? {
        guard let imageReference, !imageReference.isEmpty,
              !imageReference.hasPrefix("data:image"),
              let url = URL(string: imageReference),
              !url.isFileURL else {
            return nil
        }
        return url
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#else
private struct PlatformImage {}
#endif
