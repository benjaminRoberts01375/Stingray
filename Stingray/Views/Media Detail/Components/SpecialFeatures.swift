//
//  SpecialFeatures.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import CoreMedia
import SwiftUI

/// Displays each of the special feature types for the given media
public struct SpecialFeaturesView: View {
    /// App navigation, forwarded to each feature's player
    @Binding public var navigation: NavigationPath

    /// Streaming service used to fetch the features and their artwork
    public let streamingService: PlayerProviding & MediaImageProviding & MediaProviding
    /// Media whose special features are shown. Fetching is kicked off lazily on first appearance
    public let media: any MediaProtocol

    public var body: some View {
        VStack {
            switch self.media.specialFeatures {
            case .unloaded:
                Color.clear
                    .onAppear { self.streamingService.getExtraMediaData(for: self.media, priority: .high) }
            case .loading: ProgressView("Loading special features...")
            case .loaded(let rows):
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SpecialFeaturesRow(streamingService: self.streamingService, rowData: row, media: self.media, navigation: $navigation)
                        .focusSection()
                }
            }
        }
    }
}

/// One row of special features, all sharing a feature type.
fileprivate struct SpecialFeaturesRow: View {
    /// Streaming service used for artwork and playback
    public let streamingService: MediaProviding & MediaImageProviding & PlayerProviding
    /// Features in this row. Assumed non-empty, since the title is read from the first element
    public let rowData: [any SpecialFeatureProtocol]
    /// Row heading, taken from the first feature's type
    public let title: String
    /// Media these features belong to
    public let media: any MediaProtocol

    /// App navigation, forwarded to each feature's player
    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings: SettingsModel
    @Environment(ThemeModel.self) private var theme

    /// Creates a row for one group of special features.
    /// - Parameters:
    ///   - streamingService: Streaming service used for artwork and playback
    ///   - rowData: Features to show. Must not be empty, as the heading comes from its first element
    ///   - media: Media these features belong to
    ///   - navigation: App navigation, forwarded to each feature's player
    public init(
        streamingService: MediaProviding & MediaImageProviding & PlayerProviding,
        rowData: [any SpecialFeatureProtocol],
        media: any MediaProtocol,
        navigation: Binding<NavigationPath>
    ) {
        self.streamingService = streamingService
        self.rowData = rowData
        self.media = media
        self.title = rowData[0].featureType
        self._navigation = navigation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(self.title)
                .font(.title3.bold())
                .foregroundStyle(self.theme.currentTheme.header1)
                .padding(.top)
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(rowData, id: \.id) { specialFeature in
                        if let mediaSource = specialFeature.mediaSources.first {
                            Button {
                                navigation.append(
                                    MoviePlayerViewModel(
                                        settingsModel: self.settings,
                                        streamingService: self.streamingService,
                                        media: media,
                                        mediaSource: mediaSource,
                                        startTime: .zero
                                    )
                                )
                            }
                            label: {
                                VStack(spacing: 0) {
                                    MediaArtView(media: specialFeature, streamingService: self.streamingService, title: mediaSource.name)
                                        .frame(maxHeight: 250)
                                    if self.settings.loadThumbnailArt {
                                        Spacer(minLength: 0)
                                        Text(mediaSource.name)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(Color.white)
                                            .padding(.horizontal, 10)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .frame(width: 400, height: 325)
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}
