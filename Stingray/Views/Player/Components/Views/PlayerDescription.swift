//
//  PlayerDescription.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import SwiftUI

/// The TV player's "Description" info tab, showing the series synopsis beside the current episode's.
public struct TVPlayerDescriptionView: View {
    /// Synopsis of the show as a whole
    private let seriesDescription: String
    /// Synopsis of the playing episode. `nil` when the server has none, which hides that column
    private let episodeDescription: String?
    /// Media the metadata header is drawn from
    private let media: any MediaMetadataProtocol
    
    /// Displays the description for a tv show and episode
    /// - Parameters:
    ///   - media: To pull the logo from
    ///   - mediaSourceID: Currently playing episode
    ///   - seasons: All episodes of this series
    public init(media: any MediaMetadataProtocol, mediaSourceID: String, seasons: [(any TVSeasonProtocol)]) {
        self.seriesDescription = media.description
        self.media = media
        for season in seasons {
            for episode in season.episodes {
                if let mediaSource = episode.mediaSources.first, mediaSource.id == mediaSourceID {
                    self.episodeDescription = episode.overview
                    return
                }
            }
        }
        self.episodeDescription = nil
    }

    public var body: some View {
        VStack {
            MediaLogoHeader(media: self.media)
            HStack {
                PlayerDescriptionView(title: String(localized: "Series Description"), description: self.seriesDescription)
                if let episodeDescription {
                    PlayerDescriptionView(title: String(localized: "Episode Description"), description: episodeDescription)
                }
            }
        }
    }
}

/// The movie player's "Description" info tab.
public struct MoviePlayerDescriptionView: View {
    /// Media to load the description from
    public let media: any MediaMetadataProtocol

    public var body: some View {
        VStack {
            MediaLogoHeader(media: self.media)
            PlayerDescriptionView(title: String(localized: "Description"), description: self.media.description)
        }
    }
}

/// A single titled block of description text on the player's glass background.
fileprivate struct PlayerDescriptionView: View {
    /// Heading above the text
    public let title: String
    /// Body text
    public let description: String

    public var body: some View {
        VStack(alignment: .leading) {
            Text(self.title)
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .padding(.bottom)
            Text(self.description)
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .availableGlass()
    }
}
