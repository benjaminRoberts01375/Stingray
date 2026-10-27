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
    /// Does not include height of text
    public static let maximumDimension: CGFloat = 300

    public let media: MediaStorage
    public let url: URL?
    public let reserveTextSpace: Bool
    public let size: CGSize
    private var blurSize: CGSize { self.size / 10 }

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

        let cardSize = Self.size(for: media.mediaType, size: scale)
        self.size = cardSize
        if let mediaID = media.id {
            self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: Int(cardSize.width * 2))
        }
        else { self.url = nil }
    }
    
    /// Dictates the desired scale of the MediaCard
    public enum Scale {
        case full, shelf
    }

    /// Get the size for any media type
    /// - Parameter mediaType: Media type to get the size for
    /// - Returns: Size
    public static func size(for mediaType: MediaStorage.MediaType, size: Scale) -> CGSize {
        let baseHeight: Int = switch size {
        case .full: 300
        case .shelf: 225
        }

        switch mediaType {
        case .movie, .tvShow: return CGSize(width: baseHeight / 3 * 2, height: baseHeight) // 2:3
        case .subFolder, .homeVideo, .error: return CGSize(width: baseHeight / 3 * 4, height: baseHeight) // 4:3
        case .episode: return CGSize(width: baseHeight / 16 * 9, height: baseHeight) // 16:9
        case .example: return CGSize(width: 150, height: 200) // Different height since this doesn't go in libraries
        }
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
                        .frame(width: self.size.width, height: self.size.height)
                    }
                    else {
                        MediaCardNoImage()
                            .frame(width: self.size.width, height: self.size.height)
                    }
                    MediaCardTitleText(title: self.media.title, reserveTextSpace: self.reserveTextSpace)
                        .frame(width: self.size.width)
                }
                else {
                    MediaCardAccessibleText(title: self.media.title)
                        .frame(width: self.size.width, height: self.size.height)
                }
            }
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
            .frame(minHeight: 50)
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
