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
    
    /// Async load an image with a blur hash placeholder
    /// - Parameters:
    ///   - blurHash: Hash to display preview with
    ///   - blurSize: Resolution of the preview to show
    ///   - imageURL: URL to get the base image from
    public init(blurHash: String?, blurSize: CGSize, imageURL: URL?) {
        self.blurHash = blurHash
        self.imageURL = imageURL
        self.blurSize = blurSize
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
                        .opacity(self.fadeIn)
                        .animation(.smooth(duration: 0.5), value: self.fadeIn)
                        .onAppear { self.fadeIn = 1 }
                }
                placeholder: { EmptyView() }
            }
        }
        .task {
            if let blurHash {
                self.blurImage = UIImage(blurHash: blurHash, size: self.blurSize)
            }
        }
    }
}
