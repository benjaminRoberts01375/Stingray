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
    
    public let media: any SlimMediaProtocol
    public let url: URL?
    public let action: @MainActor () -> Void
    @State private var showError: Bool = false
    
    public static let cardSize = CGSize(width: 200, height: 370)
    
    public init(media: any SlimMediaProtocol, streamingService: StreamingServiceProtocol, action: @escaping @MainActor () -> Void) {
        self.media = media
        self.url = streamingService.getImageURL(imageType: .primary, mediaID: media.id, width: 400)
        self.action = action
    }
    
    public var body: some View {
        Button {
            if self.media.errors == nil { action() }
        }
        label: {
            VStack(spacing: 0) {
                if self.settings.loadThumbnailArt {
                    if media.imageTags?.primary != nil {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: Self.cardSize.width, height: 285)
                                .clipped()
                        } placeholder: {
                            if let blurHash = media.imageBlurHashes?.getBlurHash(for: .primary),
                               let blurImage = UIImage(blurHash: blurHash, size: .init(width: 32, height: 32)) {
                                Image(uiImage: blurImage)
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHint("Temporary placeholder for missing image", isEnabled: false)
                                    .frame(width: Self.cardSize.width, height: 285)
                                    .clipped()
                            } else {
                                MediaCardLoading()
                            }
                        }
                    } else {
                        MediaCardNoImage()
                    }
                    Text(media.title)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.labelPrimary())
                        .padding(.horizontal, 5)
                        .padding(.top, 5)
                    Spacer(minLength: 0)
                }
                else {
                    Spacer(minLength: 0)
                    Text(media.title)
                        .font(.system(size: 30))
                        .bold()
                        .multilineTextAlignment(.center)
                        .truncationMode(.tail)
                        .foregroundStyle(self.theme.currentTheme.header2())
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
        .id(media.id) // Stabilize view identity
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
