// ProfileAvatarImageView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared avatar renderer that supports three sources:
// - remote URLs
// - local file URLs
// - inline data URLs for Apple-local profile photos
//
// Local/data sources are loaded off the main thread and cached (issue #79):
// previously the image was decoded synchronously in `body` on every evaluation.

import SwiftUI
import ImageIO
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfileAvatarImageView<Placeholder: View>: View {
    let imageReference: String?
    let placeholder: () -> Placeholder

    /// Decoded local/data image, populated off the main thread.
    @State private var loadedImage: PlatformImage?

    init(imageReference: String?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageReference = imageReference
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let loadedImage {
                platformImage(loadedImage)
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
        .task(id: imageReference) {
            // Only the local/data branches need manual loading; remote uses AsyncImage.
            guard shouldLoadInline, let ref = imageReference else {
                loadedImage = nil
                return
            }
            // Decode off the main actor, then hop back to set @State.
            let decoded: PlatformImage? = await Task.detached(priority: .userInitiated) {
                Self.decodeInlineImage(reference: ref)
            }.value
            loadedImage = decoded
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

    /// Whether the reference is a local/data image (vs a remote URL or empty).
    private var shouldLoadInline: Bool {
#if canImport(UIKit) || canImport(AppKit)
        guard let imageReference, !imageReference.isEmpty else { return false }
        if imageReference.hasPrefix("data:image") { return true }
        if let url = URL(string: imageReference), url.isFileURL { return true }
        return false
#else
        return false
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

    // MARK: - Off-main decoding

    /// Decodes a local-file or data-URL avatar off the main thread.
    /// Uses ImageIO for file-based images so large avatars are downsampled
    /// instead of decoded at full resolution.
    /// `nonisolated` so it can run from a detached Task (off the main actor).
    private nonisolated static func decodeInlineImage(reference: String) -> PlatformImage? {
#if canImport(UIKit) || canImport(AppKit)
        if reference.hasPrefix("data:image"),
           let commaIndex = reference.firstIndex(of: ",") {
            let base64 = String(reference[reference.index(after: commaIndex)...])
            guard let data = Data(base64Encoded: base64) else { return nil }
            return PlatformImage(data: data)
        }

        guard let url = URL(string: reference), url.isFileURL else { return nil }
        // Downsample to a reasonable avatar size to avoid decoding a huge source
        // image at full resolution (ImageIO path).
        if let downsampled = downsampledImage(at: url, maxPixel: 256) {
            return downsampled
        }
        // Fallback: direct file read (still off the main thread here).
        return PlatformImage(contentsOfFile: url.path)
#else
        return nil
#endif
    }

#if canImport(UIKit) || canImport(AppKit)
    /// ImageIO-based downsample for file-based avatars. Returns nil on failure
    /// so callers can fall back to the synchronous read.
    private nonisolated static func downsampledImage(at url: URL, maxPixel: CGFloat) -> PlatformImage? {
#if canImport(UIKit)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
#elseif canImport(AppKit)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
#else
        return nil
#endif
    }
#endif
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#else
private struct PlatformImage {}
#endif
