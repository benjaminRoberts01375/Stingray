//
//  MediaCardView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/14/25.
//

import BlurHashKit
import SwiftUI

public struct MediaCard: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(ThemeModel.self) private var theme

    @Binding public var navigation: NavigationPath

    public static let minimumDimension: CGFloat = 200
    public static let maximumDimension: CGFloat = 370

    public let media: MediaStorage
    public let url: URL?
    public let reserveTextSpace: Bool
    public let size: CGSize
    public let blurSize: CGSize

    /// Creates a button based on the media's available art. This button navigates to the media's detail view
    /// - Parameters:
    ///   - media: Media to display and navigate on
    ///   - streamingService: Streaming service to derrive URLs from
    ///   - navigation: The app's `NavigationPath`
    ///   - reserveTextSpace: Allow the MediaCard to reserve the maximum amount of space for text
    ///   - scale: Desired size of this media card
    /// - Note: While navigation is optional, this is purely for display purposes and should be filled in.
    public init(
        media: MediaStorage,
        streamingService: MediaImageProviding,
        navigation: Binding<NavigationPath>? = nil,
        reserveTextSpace: Bool = true,
        scale: Scale = .full
    ) {
        self.media = media
        self._navigation = navigation ?? .constant(NavigationPath())
        self.reserveTextSpace = reserveTextSpace

        let scaleMultiplier: CGFloat = switch scale {
        case .full: 1
        case .shelf: 0.75
        }
        switch media {
        case .movie, .tvShow:
            self.size = CGSize(width: Self.minimumDimension * scaleMultiplier, height: Self.maximumDimension * scaleMultiplier)
            self.blurSize = CGSize(width: 20, height: 30)
            if let mediaID = media.id { self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: 400) }
            else { self.url = nil }
        case .example:
            self.size = CGSize(width: 150, height: 255)
            self.blurSize = CGSize(width: 20, height: 30)
            if let mediaID = media.id { self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: 400) }
            else { self.url = nil }
        case .homeVideo, .error:
            self.size = CGSize(width: Self.maximumDimension * scaleMultiplier, height: Self.maximumDimension * scaleMultiplier)
            self.blurSize = CGSize(width: 30, height: 20)
            if let mediaID = media.id { self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: 740) }
            else { self.url = nil }
        case .subfolder:
            self.size = CGSize(width: Self.maximumDimension * scaleMultiplier, height: Self.maximumDimension * scaleMultiplier)
            self.blurSize = CGSize(width: 30, height: 20)
            if let mediaID = media.id { self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: 555) }
            else { self.url = nil }
        }
    }
    
    /// Dictates the desired scale of the MediaCard
    public enum Scale {
        case full, shelf
    }

    public var body: some View {
        Button { self.navigation.append(self.media) }
        label: {
            VStack(alignment: .center, spacing: 0) {
                if self.settings.loadThumbnailArt {
                    if media.imageTags?.primary != nil {
                        AsyncBlurImage(
                            blurHash: self.media.imageBlurHashes?.primary,
                            blurSize: self.blurSize,
                            imageURL: self.url,
                            scaleType: .fill
                        )
                    }
                    else { MediaCardNoImage() }
                    MediaCardTitleText(title: self.media.title, reserveTextSpace: self.reserveTextSpace)
                }
                else { MediaCardAccessibleText(title: self.media.title) }
            }
            .frame(width: self.size.width, height: self.size.height)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
    }
}

fileprivate struct MediaCardTitleText: View {
    @Environment(ThemeModel.self) private var theme

    /// Title of the media being presented
    var title: String

    /// Reserve 2 lines of vertical space to display the title. False if we really need all the space we can get
    var reserveTextSpace: Bool

    var body: some View {
        Spacer(minLength: 0)
        Text(self.title)
            .multilineTextAlignment(.center)
            .lineLimit(2, reservesSpace: self.reserveTextSpace)
            .truncationMode(.tail)
            .foregroundStyle(self.theme.currentTheme.header2)
            .padding(5)
            .frame(minHeight: 50)
            .offset(y: -5)
        Spacer(minLength: 0)
    }
}

/// Large text used in the place of media art
fileprivate struct MediaCardAccessibleText: View {
    @Environment(ThemeModel.self) private var theme

    /// Title of the media being presented
    let title: String

    var body: some View {
        Spacer(minLength: 0)
        Text(self.title)
            .font(.system(size: 30))
            .bold()
            .multilineTextAlignment(.center)
            .truncationMode(.tail)
            .foregroundStyle(self.theme.currentTheme.header2)
            .padding(.horizontal)
        Spacer(minLength: 0)
    }
}

/// Stand-in artwork for media the server has no poster for.
public struct MediaCardNoImage: View {
    public var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                Text("No image available")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
