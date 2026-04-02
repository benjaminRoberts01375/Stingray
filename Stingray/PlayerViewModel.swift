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
    public var player: AVPlayer
    /// Media that contains the source to play
    public var media: any MediaProtocol
    /// Media source in play
    public var mediaSourceID: String {
        didSet {
            switch self.media.mediaType {
            case .unknown:
                break
            case .movies(let mediaSources):
                self.mediaSource = mediaSources.first { $0.id == self.mediaSourceID } ?? self.mediaSource
                return
            case .tv(let seasons):
                guard let seasons = seasons else { return }
                for season in seasons {
                    for episode in season.episodes {
                        if let mediaSource = episode.mediaSources.first, mediaSource.id == self.mediaSourceID {
                            self.mediaSource = mediaSource
                            return
                        }
                    }
                }
            }
        }
    }
    /// Quickly get the media source from the media source ID
    public private(set) var mediaSource: any MediaSourceProtocol
    
    public private(set) var settingsModel: SettingsModel
    
    /// Time to start the player at
    public var startTime: CMTime
    /// Current player progress (exposed for observation)
    public var playerProgress: PlayerProtocol?
    /// Trigger to refresh transport bar items
    public var transportBarNeedsUpdate: Bool = false
    
    /// Server to stream from
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    /// Store and restore the current navigation path
    @ObservationIgnored public var navigationPath: NavigationPath?
    
    // Hashable Conformance
    static func == (lhs: PlayerViewModel, rhs: PlayerViewModel) -> Bool {
        lhs.mediaSourceID == rhs.mediaSourceID &&
        lhs.startTime == rhs.startTime
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
        hasher.combine(startTime.seconds)
    }
    
    /// Normal init for setting up a player
    public init(
        media: any MediaProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?,
        streamingService: StreamingServiceProtocol,
        seasons: [any TVSeasonProtocol]?,
        settingsModel: SettingsModel
    ) {
        self.player = AVPlayer()
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
        self.playerProgress = nil
        self.mediaSourceID = mediaSource.id
        self.mediaSource = mediaSource
        self.media = media
        self.settingsModel = settingsModel
        
        var subtitleID: String?
        
        // Setup subtitles
        if settingsModel.usesSubtitles {
            subtitleID = self.mediaSource.subtitleStreams.first {
                $0.isDefault
            }?.id ?? self.mediaSource.subtitleStreams.first?.id
        }
        
        self.savePlaybackDate()
        self.newPlayer(
            startTime: self.startTime,
            videoID: .newID(self.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.mediaSource.videoStreams.first?.id ?? "0")),
            audioID: .newID(self.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.mediaSource.audioStreams.first?.id ?? "1")),
            subtitleID: .newID(subtitleID),
            bitrate: settingsModel.bitrate
        )
        self.player.rate = self.settingsModel.playbackSpeed.value
    }
    
    /// Dictates how the player should transition a particular stream
    public enum StreamTransitionType {
        /// Do not transition to a new stream
        case keep
        /// Update the current stream to a new ID. Nil for no stream.
        case newID(String?)
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
        videoID: StreamTransitionType = .keep,
        audioID: StreamTransitionType = .keep,
        subtitleID: StreamTransitionType = .keep,
        bitrate: Int? = nil
    ) {
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback) }
        catch { Log.warning("Failed to configure audio session: \(error)") }
        
        // Setup title and possibly a subtitle (ex. "Season 1, Episode 1" or "The Super Duper Cut")
        var title = ""
        var subtitle = ""
        switch self.media.mediaType {
        case .tv(let seasons):
            if let seasons = seasons { // TV Shows
                for season in seasons {
                    if let episode = (season.episodes.first { $0.mediaSources.first?.id == self.mediaSource.id }) {
                        subtitle = "\(season.title), Episode \(episode.episodeNumber)"
                        break
                    }
                }
                let allEpisodes = seasons.flatMap(\.episodes)
                let currentEpisode = allEpisodes.first { $0.mediaSources.first?.id == self.mediaSource.id }
                title = currentEpisode?.title ?? ""
            }
            else { title = self.mediaSource.name }
        case .movies(let sources):
            title = self.media.title
            if sources.count > 1 { subtitle = self.mediaSource.name }
        default: title = self.media.title
        }
        
        // Setup stream IDs
        let finalVideoID: String
        let finalAudioID: String
        let finalSubtitleID: String?
        switch videoID {
        case .keep: finalVideoID = self.playerProgress?.videoID ?? "0"
        case .newID(let id): finalVideoID = id ?? "0"
        }
        switch audioID {
        case .keep: finalAudioID = self.playerProgress?.audioID ?? "1"
        case .newID(let id): finalAudioID = id ?? "1"
        }
        switch subtitleID { // No subtitles when self.playerProgress?.subtitleID is nil
        case .keep: finalSubtitleID = self.playerProgress?.subtitleID
        case .newID(let id): finalSubtitleID = id
        }
        
        // We're done reading from the running player
        self.stopPlayer()
        
        // Create/update the player
        self.streamingService.playbackStart(
            mediaSource: self.mediaSource,
            videoID: finalVideoID,
            audioID: finalAudioID,
            subtitleID: finalSubtitleID,
            bitrate: bitrate ?? self.playerProgress?.bitrate,
            title: title,
            subtitle: subtitle,
            player: self.player
        )
        
        self.playerProgress = streamingService.playerProgress // Sync to view model
        self.player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player.play()
        
        // Update user settings
        self.settingsModel.usesSubtitles = self.playerProgress?.subtitleID != nil
        
        // Set up observer for when the current item finishes playing
        if self.settingsModel.autoplay {
            self.setupPlaybackEndObserver()
        }
    }
    
    /// Sets up an observer to detect when playback finishes and auto-advance to next episode
    private func setupPlaybackEndObserver() {
        // Remove any existing observers first
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // Add observer for the current item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }
    }
    
    /// Called when the current video finishes playing
    private func handlePlaybackEnded() {
        guard let seasons = self.seasons else { return }
        
        let allEpisodes = seasons.flatMap(\.episodes)
        guard let currentIndex = allEpisodes.firstIndex(where: { episode in
            episode.mediaSources.first?.id == self.mediaSource.id
        }),
        currentIndex + 1 < allEpisodes.count else {
            // No next episode, playback complete
            return
        }
        
        let nextEpisode = allEpisodes[currentIndex + 1]
        
        // Save the current episode's progress
        self.savePlaybackDate()
        
        // Update to the next episode
        self.mediaSourceID = nextEpisode.mediaSources.first?.id ?? self.mediaSourceID
        self.newPlayer(episode: nextEpisode)
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
        self.newPlayer(
            startTime: .zero,
            videoID: .newID(newVideoStream.id),
            audioID: .newID(newAudioStream.id),
            subtitleID: .newID(newSubtitleStream?.id)
        )
    }
    
    func stopPlayer() {
        player.pause()
        self.playerProgress = nil
        streamingService.playbackEnd()
    }
    
    func savePlaybackDate() {
        switch self.media.mediaType {
        case .tv(let seasons):
            if var seasons = seasons {
                for seasonIndex in seasons.indices {
                    for episodeIndex in seasons[seasonIndex].episodes.indices {
                        let episode = seasons[seasonIndex].episodes[episodeIndex]
                        if (episode.mediaSources.contains { $0.id == self.mediaSource.id }) {
                            seasons[seasonIndex].episodes[episodeIndex].lastPlayed = Date.now
                            if self.mediaSource.startPoint >= self.mediaSource.duration * 0.9 ||
                                self.mediaSource.startPoint < self.mediaSource.duration * 0.1 {
                                self.mediaSource.startPoint = 0
                            }
                        }
                    }
                }
            }
        default: break
        }
    }
    
    public func changeSpeed(_ speed: PlaybackSpeed) {
        self.player.rate = speed.value
        self.settingsModel.playbackSpeed = speed
        self.transportBarNeedsUpdate.toggle() // Trigger UI update
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player.pause()
        streamingService.playbackEnd()
    }
}
