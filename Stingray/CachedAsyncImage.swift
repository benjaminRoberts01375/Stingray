//
//  CachedAsyncImage.swift
//  Stingray
//
//  Created for performance optimization.
//

import SwiftUI

/// A view that asynchronously loads and displays an image with caching support.
/// Uses NSCache for in-memory caching to avoid redundant network requests.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard !isLoading, let url else { return }
        
        // Check cache first
        if let cached = ImageCache.shared.get(for: url) {
            cachedImage = cached
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ImageCache.shared.set(image, for: url)
                await MainActor.run {
                    cachedImage = image
                }
            }
        } catch {
            // Silently fail - placeholder will remain visible
        }
    }
}

/// Thread-safe image cache using NSCache
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    private let lock = NSLock()
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func get(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        let cost = image.jpegData(compressionQuality: 1)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    func remove(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: url as NSURL)
    }
    
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
    }
}
