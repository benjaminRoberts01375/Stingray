//
//  SpecialFeaturesRow.swift
//  Stingray
//
//  Created by Ben Roberts on 6/15/26.
//

import CoreMedia
import SwiftUI

/// Displays each of the special feature types for the given media
public struct SpecialFeaturesView: View {
    @Binding public var navigation: NavigationPath

    public let streamingService: PlayerProviding & MediaImageProviding & MediaProviding
    public let media: any MediaProtocol

    public var body: some View {
        VStack {
            switch self.media.specialFeatures {
            case .unloaded:
                Color.clear
                    .task {
                        Log.info("Attempting to get special features for \(self.media.title)...")
                        do { try await self.streamingService.getSpecialFeatures(for: self.media) }
                        catch {}
                    }
            case .loading:
                ProgressView("Loading special features...")
            case .loaded(let rows):
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SpecialFeaturesRow(streamingService: self.streamingService, rowData: row, media: self.media, navigation: $navigation)
                        .focusSection()
                }
            }
        }
    }
}

fileprivate struct SpecialFeaturesRow: View {
    public let streamingService: MediaProviding & MediaImageProviding & PlayerProviding
    public let rowData: [any SpecialFeatureProtocol]
    public let title: String
    public let media: any MediaProtocol

    @Binding public var navigation: NavigationPath

    @Environment(SettingsModel.self) private var settings: SettingsModel
    @Environment(ThemeModel.self) private var theme

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
