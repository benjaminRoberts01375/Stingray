//
//  PlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/4/25.
//

import AVKit
import SwiftUI

@Observable
final class PlayerViewModel {
    public var player: AVPlayer?
    public var selectedSubtitleID: Int?
    public var selectedAudioID: Int
    public var selectedVideoID: Int
    public var mediaID: String
    public var mediaSource: any MediaSourceProtocol
    public var startTime: CMTime
    
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    
    public init(selectedSubtitleID: Int? = nil, selectedAudioID: Int, selectedVideoID: Int, mediaSource: any MediaSourceProtocol, mediaID: String, startTime: CMTime?, streamingService: StreamingServiceProtocol, seasons: [any TVSeasonProtocol]?) {
        self.player = nil
        self.selectedSubtitleID = selectedSubtitleID
        self.selectedAudioID = selectedAudioID
        self.selectedVideoID = selectedVideoID
        self.mediaSource = mediaSource
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
        self.mediaID = mediaID
    }
    
    /// Creates a new player based on current state
    /// - Parameter startTime: Where the video should start from
    public func newPlayer(startTime: CMTime) {
        if let existingPlayer = player {
            existingPlayer.pause()
        }
        guard let playerItem = streamingService.getStreamingContent(mediaSource: mediaSource, subtitleID: selectedSubtitleID, audioID: selectedAudioID, videoID: selectedVideoID)
        else {
            return
        }
        
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player?.play()
    }
    
    /// Generate new video, audio, and subtitle IDs based on the currently playing episode. Old values are assumed to be in this view model
    /// - Parameter episode: Episode to advance to
    public func newIDsFromPreviousMedia(episode: any TVEpisodeProtocol) {
        // Get new video stream
        if let oldVideoStream = mediaSource.videoStreams.first(where: {selectedVideoID == $0.id}),
           let newVideoStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldVideoStream, streamType: .video) {
            self.selectedVideoID = newVideoStream.id
        } else {
            self.selectedVideoID = episode.mediaSources.first?.videoStreams.first?.id ?? 0
        }
        // Get new audio stream
        if let oldAudioStream = mediaSource.audioStreams.first(where: {selectedAudioID == $0.id}),
           let newAudioStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldAudioStream, streamType: .audio) {
            self.selectedAudioID = newAudioStream.id
        } else {
            self.selectedAudioID = episode.mediaSources.first?.audioStreams.first?.id ?? 1
        }
        // Get new subtitle stream - keep it off if it's off
        if self.selectedSubtitleID != nil {
            if let oldSubtitleStream = mediaSource.subtitleStreams.first(where: {selectedSubtitleID == $0.id}),
               let newSubtitleStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldSubtitleStream, streamType: .subtitle) {
                self.selectedSubtitleID = newSubtitleStream.id
            } else {
                self.selectedSubtitleID = episode.mediaSources.first?.subtitleStreams.first?.id
            }
        }
    }
}
