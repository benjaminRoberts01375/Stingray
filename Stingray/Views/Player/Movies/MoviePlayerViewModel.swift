//
//  MoviePlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVFoundation
import SwiftUI

/// Drives playback for a movie or a special feature.
/// Jellyfin has no concept of switching tracks on a live stream, so every subtitle, audio, video, or bitrate change tears the stream down
/// and builds a new one via `newPlayer(...)`. Identity is the media source ID, which is what makes it usable as a `NavigationPath` value.
@Observable
public final class MoviePlayerViewModel: AVPlayerViewModelProtocol, Hashable {
    /// User settings, read for subtitles, bitrate, and speed, and written back when the viewer changes them mid-playback
    public private(set) var settingsModel: SettingsModel

    /// Server to stream from
    @ObservationIgnored public let streamingService: PlayerProviding & MediaImageProviding

    /// Store and restore the current navigation path across a Picture in Picture handoff
    @ObservationIgnored public var navigationPath: NavigationPath?

    /// Trigger to refresh transport bar items
    public var transportBarNeedsUpdate: Bool = false

    /// Player with formatted URL already set
    public private(set) var player: AVPlayer

    /// Media the source belongs to, used for the title shown on the player
    public private(set) var media: any MediaMetadataProtocol

    /// Specific source being played. Movies may offer several versions
    public var mediaSource: any MediaSourceProtocol

    /// Current player progress
    public private(set) var playerProgress: PlayerProtocol?

    public static func == (lhs: MoviePlayerViewModel, rhs: MoviePlayerViewModel) -> Bool { lhs.mediaSource.id == rhs.mediaSource.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(media.id) }

    /// Normal init for setting up a movie player
    /// - Parameters:
    ///   - settingsModel: Load the user's settings
    ///   - streamingService: Connection to the server
    ///   - navigationPath: Stingray's navigation
    ///   - media: Media to show on screen
    ///   - mediaSource: Specific source of the media to show
    ///   - startTime: Where in the media source to start from
    public init(
        settingsModel: SettingsModel,
        streamingService: PlayerProviding & MediaImageProviding,
        navigationPath: NavigationPath? = nil,
        media: any MediaMetadataProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?
    ) {
        self.settingsModel = settingsModel
        self.streamingService = streamingService
        self.navigationPath = navigationPath
        self.player = AVPlayer()
        self.media = media
        self.mediaSource = mediaSource

        // Setup subtitles
        var subtitleID: String?
        if settingsModel.usesSubtitles {
            subtitleID = self.mediaSource.subtitleStreams.first { $0.isDefault }?.id ?? self.mediaSource.subtitleStreams.first?.id
        }

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
        videoID: StreamTransitionType,
        audioID: StreamTransitionType,
        subtitleID: StreamTransitionType,
        bitrate: Int? = nil
    ) {
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback) }
        catch { Log.warning("Failed to configure audio session: \(error)") }

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

        self.stopPlayer()

        // Create/update the player
        self.streamingService.playbackStart(
            mediaSource: self.mediaSource,
            videoID: finalVideoID,
            audioID: finalAudioID,
            subtitleID: finalSubtitleID,
            bitrate: bitrate ?? self.playerProgress?.bitrate,
            title: self.media.title,
            subtitle: self.mediaSource.name,
            player: self.player
        )

        self.player.preventsDisplaySleepDuringVideoPlayback = true // Should be default, but oh well
        self.playerProgress = streamingService.playerProgress // Sync to view model
        self.player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player.play()
    }

    /// Pauses playback and tells the server this session is over, and drops `playerProgress`
    public func stopPlayer() {
        player.pause()
        self.playerProgress = nil
        streamingService.playbackEnd()
    }

    public func changeSpeed(_ speed: PlaybackSpeed) {
        self.player.rate = speed.value
        self.settingsModel.playbackSpeed = speed
        self.transportBarNeedsUpdate.toggle() // Trigger UI update
    }
}
