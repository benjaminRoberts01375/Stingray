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
    /// Player with formatted URL already set
    public var player: AVPlayer?
    /// Subtitle identifier from the media source in play
    public var selectedSubtitleID: Int?
    /// Audio identifier from the media source in play
    public var selectedAudioID: Int
    /// Video identifier from the media source in play
    public var selectedVideoID: Int
    /// Media source in play
    public var mediaSource: any MediaSourceProtocol
    /// Time to start the player at
    public var startTime: CMTime
    /// Bitrate for the video stream
    public var bitrate: Bitrate
    
    /// Server to stream from
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    
    /// Normal init for setting up a player
    public init(
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?,
        streamingService: StreamingServiceProtocol,
        seasons: [any TVSeasonProtocol]?
    ) {
        self.player = nil
        self.selectedAudioID = mediaSource.audioStreams.first { $0.isDefault }?.id ?? (mediaSource.audioStreams.first?.id ?? 1)
        self.selectedVideoID = mediaSource.videoStreams.first { $0.isDefault }?.id ?? (mediaSource.videoStreams.first?.id ?? 0)
        self.bitrate = .full
        self.mediaSource = mediaSource
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
    }
    
    /// Creates a new player based on current state
    /// - Parameter startTime: Where the video should start from
    public func newPlayer(startTime: CMTime) {
        if let existingPlayer = player {
            existingPlayer.pause()
            streamingService.playbackEnd()
            self.player = nil
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        guard let player = streamingService.playbackStart(
            mediaSource: mediaSource,
            videoID: selectedVideoID,
            audioID: selectedAudioID,
            subtitleID: selectedSubtitleID,
            bitrate: bitrate
        )
        else { return }
        
        self.player = player
        self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player?.play()
        
        // Update user settings
        let userModel = UserModel()
        guard var currentUser = userModel.getDefaultUser() else { return }
        currentUser.usesSubtitles = selectedSubtitleID != nil
        switch self.bitrate {
        case .full:
            currentUser.bitrate = nil
        case .limited(let newBitrate):
            currentUser.bitrate = newBitrate
        }
        userModel.updateUser(currentUser)
    }
    
    /// Generate new video, audio, and subtitle IDs based on the currently playing episode. Old values are assumed to be in this view model
    /// - Parameter episode: Episode to advance to
    public func newIDsFromPreviousMedia(episode: any TVEpisodeProtocol) {
        // Get new video stream
        if let oldVideoStream = mediaSource.videoStreams.first(where: { selectedVideoID == $0.id }),
           let newVideoStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldVideoStream, streamType: .video) {
            self.selectedVideoID = newVideoStream.id
        } else {
            self.selectedVideoID = episode.mediaSources.first?.videoStreams.first?.id ?? 0
        }
        // Get new audio stream
        if let oldAudioStream = mediaSource.audioStreams.first(where: { selectedAudioID == $0.id }),
           let newAudioStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldAudioStream, streamType: .audio) {
            self.selectedAudioID = newAudioStream.id
        } else {
            self.selectedAudioID = episode.mediaSources.first?.audioStreams.first?.id ?? 1
        }
        // Get new subtitle stream - keep it off if it's off
        if self.selectedSubtitleID != nil {
            if let oldSubtitleStream = mediaSource.subtitleStreams.first(where: { selectedSubtitleID == $0.id }),
               let newSubtitleStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldSubtitleStream, streamType: .subtitle) {
                self.selectedSubtitleID = newSubtitleStream.id
            } else {
                self.selectedSubtitleID = episode.mediaSources.first?.subtitleStreams.first?.id
            }
        }
    }
    
    deinit {
        player?.pause()
        streamingService.playbackEnd()
    }
}
