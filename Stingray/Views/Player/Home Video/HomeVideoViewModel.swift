//
//  HomeVideoViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 9/26/26.
//

import AVFoundation
import SwiftUI

@Observable
public final class HomeVideoPlayerViewModel: AVPlayerViewModelProtocol, Hashable {
    public static func == (lhs: borrowing HomeVideoPlayerViewModel, rhs: borrowing HomeVideoPlayerViewModel) -> Bool {
        return lhs.mediaSource.id == rhs.mediaSource.id
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(self.mediaSource.id) }

    public let player: AVPlayer

    public private(set) var playerProgress: PlayerProtocol?

    public let mediaSource: any MediaSourceProtocol

    /// Media the source belongs to, used for the title shown on the player
    public private(set) var media: any MediaMetadataProtocol

    /// Trigger to refresh transport bar items
    public var transportBarNeedsUpdate: Bool = false

    /// Server to stream from
    @ObservationIgnored public let streamingService: PlayerProviding

    /// User settings, read for subtitles, bitrate, and speed, and written back when the viewer changes them mid-playback
    public private(set) var settingsModel: SettingsModel

    /// Store and restore the current navigation path across a Picture in Picture handoff
    @ObservationIgnored public var navigationPath: NavigationPath?

    public init(
        settingsModel: SettingsModel,
        streamingService: PlayerProviding,
        media: any MediaMetadataProtocol,
        mediaSource: any MediaSourceProtocol,
        navigationPath: NavigationPath? = nil
    ) {
        self.settingsModel = settingsModel
        self.streamingService = streamingService
        self.media = media
        self.mediaSource = mediaSource
        self.player = AVPlayer()
        self.navigationPath = navigationPath

        self.newPlayer(
            startTime: .zero,
            videoID: .newID(self.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.mediaSource.videoStreams.first?.id ?? "0")),
            audioID: .newID(self.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.mediaSource.audioStreams.first?.id ?? "1")),
            subtitleID: .newID("0"),
            bitrate: settingsModel.bitrate
        )
        self.player.rate = self.settingsModel.playbackSpeed.value
    }

    public func newPlayer(
        startTime: CMTime,
        videoID: StreamTransitionType,
        audioID: StreamTransitionType,
        subtitleID: StreamTransitionType,
        bitrate: Int?
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
        self.playerProgress = self.streamingService.playerProgress // Sync to view model
        self.player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player.play()
    }

    public func changeSpeed(_ speed: PlaybackSpeed) {
        self.player.rate = speed.value
        self.settingsModel.playbackSpeed = speed
        self.transportBarNeedsUpdate.toggle() // Trigger UI update
    }

    /// Pauses playback and tells the server this session is over, and drops `playerProgress`
    public func stopPlayer() {
        player.pause()
        self.playerProgress = nil
        streamingService.playbackEnd()
    }
}
