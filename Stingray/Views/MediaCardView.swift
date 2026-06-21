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
    
    @State private var showError: Bool = false
    @State private var blurImage: UIImage?
    
    @Binding public var navigation: NavigationPath
    
    public static let cardSize = CGSize(width: 200, height: 370)
    private static let imageHeight: CGFloat = MediaCard.cardSize.height + 15
    
    public let media: any SlimMediaProtocol
    public let url: URL?
    public let reserveTextSpace: Bool
    
    /// Creates a button based on the media's available art. This button navigates to the media's detail view
    /// - Parameters:
    ///   - media: Media to display and navigate on
    ///   - streamingService: Streaming service to derrive URLs from
    ///   - navigation: The app's `NavigationPath`
    ///   - reserveTextSpace: Allow the MediaCard to reserve the maximum amount of space for text
    /// - Note: While navigation is optional, this is purely for display purposes and should be filled in.
    public init(
        media: any SlimMediaProtocol,
        streamingService: StreamingServiceProtocol,
        navigation: Binding<NavigationPath>? = nil,
        reserveTextSpace: Bool = true
    ) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 400)
        self._navigation = navigation ?? .constant(NavigationPath())
        self.reserveTextSpace = reserveTextSpace
    }
    
    public var body: some View {
        Button { if self.media.errors == nil {
            if let media = self.media as? (any MediaProtocol) { // Shortcut
                self.navigation.append(AnyMedia(media: media))
                Log.info("Shortcut")
                return
            }
            Log.info("Longcut")
            self.navigation.append(self.media) }
        }
        label: {
            VStack(spacing: 0) {
                if self.settings.loadThumbnailArt {
                    if media.imageTags?.primary != nil {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            if let blurImage {
                                Image(uiImage: blurImage)
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                            }
                            else { MediaCardLoading() }
                        }
                        .frame(width: Self.cardSize.width)
                        .frame(minHeight: 0, maxHeight: Self.imageHeight)
                        .clipped()
                    }
                    else { MediaCardNoImage() }
                    Text(self.media.title)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: self.reserveTextSpace)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2)
                        .padding(5)
                    Spacer(minLength: 0)
                }
                else {
                    Spacer(minLength: 0)
                    Text(self.media.title)
                        .font(.system(size: 30))
                        .bold()
                        .multilineTextAlignment(.center)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2)
                        .padding(.horizontal)
                        .frame(width: Self.cardSize.width)
                    Spacer(minLength: 0)
                }
            }
            .background {
                if !(self.media.errors?.isEmpty ?? true) {
                    Color.red.opacity(0.25)
                }
            }
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.card)
        .contextMenu {
            if self.media.errors != nil {
                Button("Show Error", systemImage: "exclamationmark.octagon", role: .destructive) { self.showError = true }
            }
        }
        .sheet(isPresented: $showError) {
            if let errors = self.media.errors {
                ErrorExpandedView(errorDesc: errors.rDescription)
            }
        }
        .frame(idealWidth: Self.cardSize.width, idealHeight: Self.cardSize.height)
        .task(id: self.media.id, priority: .background) {
            guard let blurHash = self.media.imageBlurHashes?.primary
            else { return }
            let decoded = await Task.detached(priority: .background) {
                return UIImage(blurHash: blurHash, size: CGSize(width: 32, height: 32))
            }.value
            self.blurImage = decoded
        }
    }
}

public struct MediaCardLoading: View {
    public var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack {
                ProgressView()
                Text("Getting thumbnail...")
            }
        }
    }
}

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
