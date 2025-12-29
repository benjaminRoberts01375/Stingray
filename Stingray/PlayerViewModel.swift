//
//  PlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/4/25.
//

import AVKit
import SwiftUI

@Observable
final class PlayerViewModel: Hashable {
    /// Player with formatted URL already set
    public var player: AVPlayer?
    /// Media source in play
    public var mediaSource: any MediaSourceProtocol
    /// Time to start the player at
    public var startTime: CMTime
    /// Current player progress (exposed for observation)
    public var playerProgress: PlayerProtocol?
    
    /// Server to stream from
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    
    // Hashable Conformance
    static func == (lhs: PlayerViewModel, rhs: PlayerViewModel) -> Bool {
        lhs.mediaSource.id == rhs.mediaSource.id &&
        lhs.startTime == rhs.startTime
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaSource.id)
        hasher.combine(startTime.seconds)
    }
    
    /// Normal init for setting up a player
    public init(
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?,
        streamingService: StreamingServiceProtocol,
        seasons: [any TVSeasonProtocol]?
    ) {
        self.player = nil
        self.mediaSource = mediaSource
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
        self.playerProgress = nil
    }
    
    /// Creates a new player based on current state
    /// - Parameters:
    ///   - startTime: Where the video should start from
    ///   - videoID: Video stream identifier. Nil = existing video ID
    ///   - audioID: Audio stream identifier. Nil = existing audio ID
    ///   - subtitleID: Subtitle stream identifier (empty for no subtitles). Nil = existing subtitle ID
    ///   - bitrate: The video's bitrate in bits per second
    public func newPlayer(
        startTime: CMTime,
        videoID: String? = nil,
        audioID: String? = nil,
        subtitleID: String? = nil,
        bitrate: Bitrate? = nil
    ) {
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
            videoID: videoID ?? self.playerProgress?.videoID ?? "0",
            audioID: audioID ?? self.playerProgress?.audioID ?? "1",
            subtitleID: subtitleID ?? self.playerProgress?.subtitleID, // nil is no subtitles
            bitrate: bitrate ?? self.playerProgress?.bitrate ?? .full
        )
        else { return }
        
        self.player = player
        self.playerProgress = streamingService.playerProgress // Sync to view model
        self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player?.play()
        
        // Update user settings
        let userModel = UserModel()
        guard var currentUser = userModel.getDefaultUser() else { return }
        currentUser.usesSubtitles = self.playerProgress?.subtitleID != nil
        switch bitrate {
        case .full, .none:
            currentUser.bitrate = nil
        case .limited(let newBitrate):
            currentUser.bitrate = newBitrate
        }
        userModel.updateUser(currentUser)
    }
    
    /// Creates a new player based on current state and new episode
    /// - Parameter episode: Episode to transition into
    public func newPlayer(episode: any TVEpisodeProtocol) {
        guard let oldVideoStream = mediaSource.videoStreams.first(where: { self.playerProgress?.videoID == $0.id }),
              let newVideoStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldVideoStream, streamType: .video),
              let oldAudioStream = mediaSource.audioStreams.first(where: { self.playerProgress?.audioID == $0.id }),
              let newAudioStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldAudioStream, streamType: .audio)
        else { return }
        var newSubtitleStream: (any MediaStreamProtocol)?
        if let oldSubtitleStream = mediaSource.subtitleStreams.first(where: { self.playerProgress?.subtitleID == $0.id }) {
            newSubtitleStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldSubtitleStream, streamType: .subtitle)
        }
        self.newPlayer(startTime: .zero, videoID: newVideoStream.id, audioID: newAudioStream.id, subtitleID: newSubtitleStream?.id)
    }
    
    deinit {
        player?.pause()
        streamingService.playbackEnd()
    }
}
