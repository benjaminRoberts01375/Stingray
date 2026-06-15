//
//  Background.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import SwiftUI

public struct MediaBackgroundView: View {
    /// Preview for the background image
    @State private var blurImage: UIImage?
    /// Controls the loaded background opacity
    @State private var fadeBackgroundIn: Double
    /// Blurs the background
    @Binding public var shouldBlurBackground: Bool

    /// Media to pull background info from
    public let media: any MediaProtocol
    /// URL to get the image from
    public let backgroundImageURL: URL?

    /// Sets up an image that first shows a blurry background, then the loaded image
    /// - Parameters:
    ///   - media: Media to load blur from
    ///   - backgroundImageURL: Image to load
    ///   - shouldBlurBackground: Track if the loaded image should be blurred
    public init(media: any MediaProtocol, backgroundImageURL: URL?, shouldBlurBackground: Binding<Bool>) {
        self.fadeBackgroundIn = 0
        self._shouldBlurBackground = shouldBlurBackground
        self.media = media
        self.backgroundImageURL = backgroundImageURL
    }

    public var body: some View {
        ZStack {
            AsyncBlurImage(
                blurHash: self.media.imageBlurHashes?.backdrop,
                blurSize: CGSize(width: 32, height: 18),
                imageURL: backgroundImageURL
            )
            Color.clear // Blurry background
                .background(.thinMaterial.opacity(self.shouldBlurBackground ? 1 : 0))
                .animation(.smooth(duration: 0.5), value: self.shouldBlurBackground)
        }
        .allowsHitTesting(false)
    }
}
