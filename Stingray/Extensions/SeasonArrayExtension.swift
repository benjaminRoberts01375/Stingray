//
//  SeasonArrayExtension.swift
//  Stingray
//
//  Created by Ben Roberts on 2/5/26.
//

import Foundation

/// Extend the array of `any TVSeasonProtocol` to include a next up function
extension Array where Element == any TVSeasonProtocol {
    /// Quickly get the next episode to watch.
    /// - Returns: The next episode to watch, nil if the array is empty.
    func nextUp() -> (any TVEpisodeProtocol)? {
        let allEpisodes = self.flatMap(\.episodes)
        // If the first episode hasn't been played suggest it
        if let firstEpisode = allEpisodes.first, firstEpisode.lastPlayed == nil {
            return firstEpisode
        }
        // Get the most recent episode
        guard let mostRecentEpisode = (allEpisodes.enumerated().max { previousEpisode, currentEpisode in
            return previousEpisode.element.lastPlayed ?? .distantPast < currentEpisode.element.lastPlayed ?? .distantPast
        }),
              let mostRecentMediaSource = mostRecentEpisode.element.mediaSources.first
        else { return allEpisodes.first } // failing getting the most recent, return the first episode
        
        // Watched previous episode all the way through
        if mostRecentMediaSource.startPoint == 0 {
            if mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
                return allEpisodes.first ?? mostRecentEpisode.element
            }
            return allEpisodes[mostRecentEpisode.offset + 1]
        }
        
        // Likely marked by Stingray that the user didn't finish
        if mostRecentMediaSource.startPoint < 0.9 * mostRecentMediaSource.duration {
            return mostRecentEpisode.element
        }
        
        // User finished the series, recommend the first episode again
        if mostRecentEpisode.offset + 1 > allEpisodes.count - 1 {
            return allEpisodes.first ?? mostRecentEpisode.element
        }
        return allEpisodes[mostRecentEpisode.offset + 1]
    }
}
