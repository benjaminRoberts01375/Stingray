//
//  AsyncBlurImageView.swift
//  Stingray
//
//  Created by Ben Roberts on 6/14/26.
//

import BlurHashKit
import SwiftUI

public struct AsyncBlurImage: View {
    /// The preview image generated from a blur hash
    @State private var blurImage: UIImage?
    /// Opacity of the full-resolution image
    @State private var fadeIn: Double = 0
    
    /// Blurry hash of the preview image
    private let blurHash: String?
    /// Size of the hash to
    private let blurSize: CGSize
    /// Image to download the full resolution image
    private let imageURL: URL?
    /// Describes the scaling of just the image
    private let scaleType: ContentMode
    
    /// Async load an image with a blur hash placeholder
    /// - Parameters:
    ///   - blurHash: Hash to display preview with
    ///   - blurSize: Resolution of the preview to show
    ///   - imageURL: URL to get the base image from
    ///   - scaleType: Describes the scaling of just the image, not the blur
    public init(blurHash: String?, blurSize: CGSize, imageURL: URL?, scaleType: ContentMode = .fill) {
        self.blurHash = blurHash
        self.imageURL = imageURL
        self.blurSize = blurSize
        self.scaleType = scaleType
    }
    
    public var body: some View {
        ZStack {
            if let blurImage {
                Image(uiImage: blurImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHint("Placeholder image", isEnabled: false)
            }
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: self.scaleType)
                        .opacity(self.fadeIn)
                        .animation(.smooth(duration: 0.5), value: self.fadeIn)
                        .onAppear { self.fadeIn = 1 }
                }
                placeholder: { EmptyView() }
            }
        }
        // Re-decode only when the hash changes, and never on the main actor.
        .task(id: self.blurHash) {
            self.blurImage = await BlurHashImageCache.shared.image(hash: self.blurHash, size: self.blurSize)
        }
    }
}

/// Caches decoded blur hash placeholder images and performs the expensive decode off the main actor.
///
/// Blur hash decoding is CPU-heavy. This actor moves the work off the main
/// thread and memoizes results so repeated hashes (and re-appearing cells) skip the decode entirely.
private actor BlurHashImageCache {
    /// Cache to pull `UIImage`s from
    static let shared = BlurHashImageCache()
    
    /// A thread-safe, memory-pressure-aware cache of decoded placeholder images keyed by hash + size.
    /// Since a large library may have a couple thousand images, we have to work by approximate image size otherwise we'll just be
    /// clearling the cache left right and center
    private let cache = NSCache<NSString, UIImage>()
    
    /// Singleton setup for allowed memory usage
    private init() { self.cache.totalCostLimit = 16 * 1024 * 1024 }
    
    /// Returns the decoded placeholder for the given hash, decoding (and caching) off the main actor on a miss.
    /// - Parameters:
    ///   - hash: The blur hash to decode. A `nil` hash yields a `nil` image.
    ///   - size: The resolution to decode the placeholder at.
    /// - Returns: The decoded image, or `nil` if there is no hash or decoding fails.
    func image(hash: String?, size: CGSize) -> UIImage? {
        guard let hash else { return nil }
        
        let key = "\(hash)|\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = self.cache.object(forKey: key) { return cached }
        
        guard let decoded = UIImage(blurHash: hash, size: size)
        else { return nil }
        // Cost = decoded RGBA pixel bytes, so the cache evicts based on real memory footprint.
        let cost = Int(decoded.size.width * decoded.scale * decoded.size.height * decoded.scale) * 4
        self.cache.setObject(decoded, forKey: key, cost: cost)
        return decoded
    }
}
