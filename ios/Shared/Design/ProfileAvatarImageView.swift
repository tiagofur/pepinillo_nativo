// ProfileAvatarImageView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared avatar renderer that supports three sources:
// - remote URLs
// - local file URLs
// - inline data URLs for Apple-local profile photos

import SwiftUI
import UIKit

struct ProfileAvatarImageView<Placeholder: View>: View {
    let imageReference: String?
    let placeholder: () -> Placeholder

    init(imageReference: String?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageReference = imageReference
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = resolvedInlineImage {
            Image(uiImage: image)
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

    private var resolvedInlineImage: UIImage? {
        guard let imageReference, !imageReference.isEmpty else {
            return nil
        }

        if imageReference.hasPrefix("data:image"),
           let commaIndex = imageReference.firstIndex(of: ",") {
            let base64 = String(imageReference[imageReference.index(after: commaIndex)...])
            guard let data = Data(base64Encoded: base64) else {
                return nil
            }
            return UIImage(data: data)
        }

        guard let url = URL(string: imageReference), url.isFileURL else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
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