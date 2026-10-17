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

    public static let cardSize = CGSize(width: 200, height: 370)

    public let media: MediaStorage
    public let url: URL?
    public let reserveTextSpace: Bool
    public let size: CGSize

    /// Creates a button based on the media's available art. This button navigates to the media's detail view
    /// - Parameters:
    ///   - media: Media to display and navigate on
    ///   - streamingService: Streaming service to derrive URLs from
    ///   - navigation: The app's `NavigationPath`
    ///   - reserveTextSpace: Allow the MediaCard to reserve the maximum amount of space for text
    ///   - size: Visual size of the card. Defaults to `cardSize`.
    /// - Note: While navigation is optional, this is purely for display purposes and should be filled in.
    public init(
        media: MediaStorage,
        streamingService: MediaImageProviding,
        navigation: Binding<NavigationPath>? = nil,
        reserveTextSpace: Bool = true,
        size: CGSize = MediaCard.cardSize
    ) {
        self.media = media
        if let mediaID = media.id { self.url = streamingService.getImageURL(imageType: .primary, mediaID: mediaID, width: 400) }
        else { self.url = nil }
        self._navigation = navigation ?? .constant(NavigationPath())
        self.reserveTextSpace = reserveTextSpace
        self.size = size
    }

    public var body: some View {
        Button { self.navigation.append(self.media) }
        label: {
            VStack(spacing: 0) {
                if self.settings.loadThumbnailArt {
                    if media.imageTags?.primary != nil {
                        AsyncBlurImage(
                            blurHash: self.media.imageBlurHashes?.primary,
                            blurSize: CGSize(width: 20, height: 30),
                            imageURL: self.url,
                            scaleType: .fill
                        )
                    }
                    else { MediaCardNoImage() }
                    Spacer(minLength: 0)
                    Text(self.media.title ?? "")
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: self.reserveTextSpace)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2)
                        .padding(5)
                        .frame(minHeight: 50)
                        .offset(y: -5)
                    Spacer(minLength: 0)
                }
                else { MediaCardAccessibleText(title: self.media.title ?? "") }
            }
            .frame(width: self.size.width, height: self.size.height)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
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
