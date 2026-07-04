//
//  PlayerDescription.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import SwiftUI

public struct PlayerDescriptionView: View {
    /// Media to describe
    public let media: any MediaProtocol
    public let mediaSource: any MediaSourceProtocol

    public var body: some View {
        VStack {
            MediaLogoHeader(media: self.media)
                .padding(.bottom)
                .shadow(color: .black.opacity(1), radius: 10)

            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    let isTVSeries = {
                        if case .tv = self.media.mediaType {
                            return true
                        }
                        return false
                    }()
                    Text("\(isTVSeries ? "Series " : "")Description")
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .padding(.bottom)
                    Text(self.media.description)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .availableGlass()

                switch media.mediaType {
                case .movies: EmptyView()
                case .tv(let seasons):
                    if let seasons = seasons,
                       let episode = (seasons.flatMap(\.episodes).first { $0.mediaSources.first?.id == self.mediaSource.id }),
                       let episodeDescription = episode.overview {
                        VStack(alignment: .leading) {
                            Text("Episode Description")
                                .font(.title3.bold())
                                .multilineTextAlignment(.leading)
                            Text(episodeDescription)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                        .availableGlass()
                    }
                }
            }
        }
    }
}
