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
    /// Video identifier from the media source in play
    public var selectedVideoID: String
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
        self.selectedVideoID = mediaSource.videoStreams.first { $0.isDefault }?.id ?? (mediaSource.videoStreams.first?.id ?? "0")
        self.bitrate = .full
        self.mediaSource = mediaSource
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
    }
    
    /// Creates a new player based on current state
    /// - Parameters:
    ///   - startTime: Where the video should start from
    ///   - videoID: Video stream identifier. Nil = existing video ID
    ///   - audioID: Audio stream identifier. Nil = existing audio ID
    ///   - subtitleID: Subtitle stream identifier (empty for no subtitles). Nil = existing subtitle ID
    public func newPlayer(startTime: CMTime, videoID: String? = nil, audioID: String? = nil, subtitleID: String? = nil) {
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
            videoID: videoID ?? self.streamingService.playerProgress?.videoID ?? "0",
            audioID: audioID ?? self.streamingService.playerProgress?.audioID ?? "1",
            subtitleID: subtitleID ?? self.streamingService.playerProgress?.subtitleID, // nil is no subtitles
            bitrate: bitrate
        )
        else { return }
        
        self.player = player
        self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player?.play()
        
        // Update user settings
        let userModel = UserModel()
        guard var currentUser = userModel.getDefaultUser() else { return }
        currentUser.usesSubtitles = self.streamingService.playerProgress?.subtitleID != nil
        switch self.bitrate {
        case .full:
            currentUser.bitrate = nil
        case .limited(let newBitrate):
            currentUser.bitrate = newBitrate
        }
        userModel.updateUser(currentUser)
    }
    
    /// Creates a new player based on current state and new episode
    /// - Parameter episode: Episode to transition into
    public func newPlayer(episode: any TVEpisodeProtocol) {
        guard let oldVideoStream = mediaSource.videoStreams.first(where: { self.streamingService.playerProgress?.videoID == $0.id }),
              let newVideoStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldVideoStream, streamType: .video),
              let oldAudioStream = mediaSource.audioStreams.first(where: { self.streamingService.playerProgress?.audioID == $0.id }),
              let newAudioStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldAudioStream, streamType: .audio)
        else { return }
        var newSubtitleStream: (any MediaStreamProtocol)?
        if let oldSubtitleStream = mediaSource.subtitleStreams.first(where: { self.streamingService.playerProgress?.subtitleID == $0.id }) {
            newSubtitleStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldSubtitleStream, streamType: .subtitle)
        }
        self.newPlayer(startTime: .zero, videoID: newVideoStream.id, audioID: newAudioStream.id, subtitleID: newSubtitleStream?.id)
    }
    
    deinit {
        player?.pause()
        streamingService.playbackEnd()
    }
}
