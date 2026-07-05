//
//  PlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/4/25.
//

import AVKit
import SwiftUI

@Observable
public final class TVPlayerViewModel: AVPlayerViewModelProtocol, Hashable {
    /// Player with formatted URL already set
    public private(set) var player: AVPlayer

    /// Media that contains the source to play
    public private(set) var media: any MediaMetadataProtocol

    /// Quickly get the media source from the media source ID
    public var mediaSource: any MediaSourceProtocol

    public private(set) var settingsModel: SettingsModel

    /// Current player progress (exposed for observation)
    public var playerProgress: PlayerProtocol?
    /// Trigger to refresh transport bar items
    public var transportBarNeedsUpdate: Bool = false

    /// Server to stream from
    @ObservationIgnored public let streamingService: PlayerProviding & MediaImageProviding
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public private(set) var seasons: [(any TVSeasonProtocol)]
    /// Store and restore the current navigation path
    @ObservationIgnored public var navigationPath: NavigationPath?

    // Hashable Conformance
    public static func == (lhs: TVPlayerViewModel, rhs: TVPlayerViewModel) -> Bool {
        lhs.mediaSource.id == rhs.mediaSource.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
    }

    /// Normal init for setting up a player
    public init(
        media: any MediaMetadataProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?,
        streamingService: PlayerProviding & MediaImageProviding,
        seasons: [any TVSeasonProtocol],
        settingsModel: SettingsModel
    ) {
        self.player = AVPlayer()
        self.streamingService = streamingService
        self.seasons = seasons
        self.playerProgress = nil
        self.mediaSource = mediaSource
        self.media = media
        self.settingsModel = settingsModel

        var subtitleID: String?

        // Setup subtitles
        if settingsModel.usesSubtitles {
            subtitleID = self.mediaSource.subtitleStreams.first { $0.isDefault }?.id ?? self.mediaSource.subtitleStreams.first?.id
        }

        self.savePlaybackDate()
        self.newPlayer(
            startTime: startTime ?? .zero,
            videoID: .newID(self.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.mediaSource.videoStreams.first?.id ?? "0")),
            audioID: .newID(self.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.mediaSource.audioStreams.first?.id ?? "1")),
            subtitleID: .newID(subtitleID),
            bitrate: settingsModel.bitrate
        )
        self.player.rate = self.settingsModel.playbackSpeed.value
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
        for season in self.seasons {
            if let episode = (season.episodes.first { $0.mediaSources.first?.id == self.mediaSource.id }) {
                subtitle = "\(season.title), Episode \(episode.episodeNumber)"
                break
            }
        }
        let allEpisodes = self.seasons.flatMap(\.episodes)
        let currentEpisode = allEpisodes.first { $0.mediaSources.first?.id == self.mediaSource.id }
        title = currentEpisode?.title ?? ""

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

        self.player.preventsDisplaySleepDuringVideoPlayback = true // Should be default, but oh well
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
        let allEpisodes = self.seasons.flatMap(\.episodes)
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
        self.mediaSource = nextEpisode.mediaSources.first ?? self.mediaSource
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

    public func stopPlayer() {
        player.pause()
        self.playerProgress = nil
        streamingService.playbackEnd()
    }

    public func savePlaybackDate() {
        for seasonIndex in self.seasons.indices {
            for episodeIndex in self.seasons[seasonIndex].episodes.indices {
                let episode = self.seasons[seasonIndex].episodes[episodeIndex]
                if (episode.mediaSources.contains { $0.id == self.mediaSource.id }) {
                    self.seasons[seasonIndex].episodes[episodeIndex].lastPlayed = Date.now
                    if self.mediaSource.startPoint >= self.mediaSource.duration * 0.9 ||
                        self.mediaSource.startPoint < self.mediaSource.duration * 0.1 {
                        self.mediaSource.startPoint = 0
                    }
                }
            }
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
