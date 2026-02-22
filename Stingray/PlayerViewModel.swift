//
//  PlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/4/25.
//

import AVKit
import Combine
import SwiftUI

/// Parsed subtitle cue from a VTT file
struct SubtitleCue {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

@Observable
final class PlayerViewModel: Hashable {
    /// Player with formatted URL already set
    public var player: AVPlayer?
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

    /// Time to start the player at
    public var startTime: CMTime
    /// Current player progress (exposed for observation)
    public var playerProgress: PlayerProtocol?
    /// Current subtitle text to display as overlay (nil = no subtitle visible)
    public var currentSubtitleText: String?

    /// Server to stream from
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    /// Store and restore the current navigation path
    @ObservationIgnored public var navigationPath: NavigationPath?
    /// Subscription for observing AVPlayerItem status during track switches
    @ObservationIgnored private var itemStatusCancellable: AnyCancellable?
    /// Parsed subtitle cues for the current text subtitle
    @ObservationIgnored private var subtitleCues: [SubtitleCue] = []
    /// Periodic time observer for updating subtitle display
    @ObservationIgnored private var subtitleTimeObserver: Any?

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
        seasons: [any TVSeasonProtocol]?
    ) {
        self.player = nil
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
        self.playerProgress = nil
        self.mediaSourceID = mediaSource.id
        self.mediaSource = mediaSource
        self.media = media

        var subtitleID: String?
        var bitrate: Bitrate = .full

        if let defaultUser = UserModel.shared.getDefaultUser() {
            // Setup subtitles
            if defaultUser.usesSubtitles {
                subtitleID = self.mediaSource.subtitleStreams.first {
                    $0.isDefault
                }?.id ?? self.mediaSource.subtitleStreams.first?.id
            }
            // Setup bitrate
            if let bitrateBits = defaultUser.bitrate {
                bitrate = .limited(bitrateBits)
            }
        }

        self.savePlaybackDate()
        self.newPlayer(
            startTime: self.startTime,
            videoID: self.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.mediaSource.videoStreams.first?.id ?? "0"),
            audioID: self.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.mediaSource.audioStreams.first?.id ?? "1"),
            subtitleID: subtitleID,
            bitrate: bitrate
        )

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
        let isTrackSwitch = self.player != nil

        if !isTrackSwitch {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
        }

        // Clear any existing subtitle overlay
        clearSubtitles()

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

        let resolvedVideoID = videoID ?? self.playerProgress?.videoID ?? "0"
        let resolvedAudioID = audioID ?? self.playerProgress?.audioID ?? "1"
        let resolvedSubtitleID = subtitleID ?? self.playerProgress?.subtitleID
        let resolvedBitrate = bitrate ?? self.playerProgress?.bitrate ?? .full

        if isTrackSwitch, let existingPlayer = self.player {
            // Track switch: reuse existing AVPlayer to preserve the HDR/DV pipeline.
            // Recreating the player destroys the color space and tone mapping state,
            // which causes a blue screen on HDR content.
            guard let newItem = streamingService.playbackSwitchTrack(
                existingPlayer: existingPlayer,
                mediaSource: self.mediaSource,
                videoID: resolvedVideoID,
                audioID: resolvedAudioID,
                subtitleID: resolvedSubtitleID,
                bitrate: resolvedBitrate,
                title: title,
                subtitle: subtitle
            ) else { return }

            // Cancel any previous item status observation
            self.itemStatusCancellable?.cancel()

            existingPlayer.replaceCurrentItem(with: newItem)
            self.playerProgress = streamingService.playerProgress
            existingPlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            existingPlayer.play()

            // Observe the new item's status to handle load failures gracefully.
            // If the new stream fails (e.g. transcoding timeout for image-based subtitles),
            // fall back to playback without subtitles.
            self.itemStatusCancellable = newItem.publisher(for: \.status)
                .sink { [weak self] status in
                    guard let self = self else { return }
                    switch status {
                    case .failed:
                        let errorDescription = newItem.error?.localizedDescription ?? "Unknown error"
                        print("AVPlayerItem failed to load: \(errorDescription)")

                        // If we were switching subtitles on, retry without subtitles
                        if resolvedSubtitleID != nil {
                            print("Retrying playback without subtitles...")
                            self.itemStatusCancellable?.cancel()
                            self.newPlayer(
                                startTime: startTime,
                                videoID: resolvedVideoID,
                                audioID: resolvedAudioID,
                                subtitleID: nil,
                                bitrate: resolvedBitrate
                            )
                        }
                    case .readyToPlay:
                        self.itemStatusCancellable?.cancel()
                        self.itemStatusCancellable = nil
                    default:
                        break
                    }
                }
        } else {
            // Initial playback: create a new player from scratch
            guard let player = streamingService.playbackStart(
                mediaSource: self.mediaSource,
                videoID: resolvedVideoID,
                audioID: resolvedAudioID,
                subtitleID: resolvedSubtitleID,
                bitrate: resolvedBitrate,
                title: title,
                subtitle: subtitle
            )
            else { return }

            self.player = player
            self.playerProgress = streamingService.playerProgress
            self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
            self.player?.play()
        }

        // Load text-based subtitles as VTT overlay
        if let subID = resolvedSubtitleID, isTextBasedSubtitle(subID) {
            loadExternalSubtitles(subtitleIndex: subID)
        }

        // Update user settings
        guard var currentUser = UserModel.shared.getDefaultUser() else { return }
        currentUser.usesSubtitles = self.playerProgress?.subtitleID != nil
        switch bitrate {
        case .full, .none:
            currentUser.bitrate = nil
        case .limited(let newBitrate):
            currentUser.bitrate = newBitrate
        }
        UserModel.shared.updateUser(currentUser)
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

    // MARK: - External Subtitle (VTT Overlay)

    /// Check if a subtitle stream is text-based (can be rendered client-side)
    private func isTextBasedSubtitle(_ subtitleID: String?) -> Bool {
        guard let subtitleID = subtitleID else { return false }
        guard let stream = self.mediaSource.subtitleStreams.first(where: { $0.id == subtitleID }) else { return false }
        let imageBasedCodecs = ["pgssub", "pgs", "dvdsub", "vobsub", "sub", "dvbsub", "dvb_subtitle", "xsub"]
        return !imageBasedCodecs.contains(stream.codec.lowercased())
    }

    /// Fetch VTT subtitle content from Jellyfin and set up the time observer for overlay display.
    private func loadExternalSubtitles(subtitleIndex: String) {
        let mediaSourceID = self.mediaSource.id
        let service = self.streamingService
        Task {
            guard let vttContent = await service.fetchSubtitleContent(
                mediaSourceID: mediaSourceID,
                subtitleIndex: subtitleIndex
            ) else {
                print("Failed to fetch VTT subtitle content")
                return
            }

            let cues = Self.parseVTT(vttContent)
            print("Loaded \(cues.count) subtitle cues")

            await MainActor.run {
                self.subtitleCues = cues
                self.startSubtitleTimeObserver()
            }
        }
    }

    /// Remove subtitle overlay and stop the time observer.
    private func clearSubtitles() {
        if let observer = subtitleTimeObserver, let player = self.player {
            player.removeTimeObserver(observer)
        }
        subtitleTimeObserver = nil
        subtitleCues = []
        currentSubtitleText = nil
    }

    /// Start a periodic time observer that updates the displayed subtitle text.
    private func startSubtitleTimeObserver() {
        guard let player = self.player else { return }
        // Remove any existing observer
        if let observer = subtitleTimeObserver {
            player.removeTimeObserver(observer)
        }

        // Update subtitles 4 times per second
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        subtitleTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            // Binary search would be optimal, but linear search is fine for typical subtitle counts
            let activeCue = self.subtitleCues.first { seconds >= $0.startTime && seconds < $0.endTime }
            let newText = activeCue?.text
            if self.currentSubtitleText != newText {
                self.currentSubtitleText = newText
            }
        }
    }

    /// Parse a WebVTT string into an array of subtitle cues.
    static func parseVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Look for timestamp lines: "00:01:49.509 --> 00:01:50.575"
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                guard parts.count == 2 else {
                    i += 1
                    continue
                }

                // Remove positioning metadata after timestamp (e.g. "region:subtitle line:90%")
                let startStr = parts[0].trimmingCharacters(in: .whitespaces)
                let endPart = parts[1].trimmingCharacters(in: .whitespaces)
                let endStr = endPart.components(separatedBy: " ").first ?? endPart

                guard let startTime = parseVTTTimestamp(startStr),
                      let endTime = parseVTTTimestamp(endStr) else {
                    i += 1
                    continue
                }

                // Collect text lines until empty line or end
                var textLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    // Strip basic HTML tags
                    let cleanLine = lines[i]
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    textLines.append(cleanLine)
                    i += 1
                }

                let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
                }
            } else {
                i += 1
            }
        }

        return cues
    }

    /// Parse a VTT timestamp string (HH:MM:SS.mmm or MM:SS.mmm) into seconds.
    private static func parseVTTTimestamp(_ str: String) -> TimeInterval? {
        let parts = str.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }

        if parts.count == 3 {
            // HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        } else {
            // MM:SS.mmm
            guard let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        }
    }

    func stopPlayer() {
        clearSubtitles()
        itemStatusCancellable?.cancel()
        itemStatusCancellable = nil
        player?.pause()
        player = nil
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

                            print(self.mediaSource.startPoint, self.mediaSource.duration * 0.1, self.mediaSource.duration * 0.9, )
                        }
                    }
                }
            }
        default: break
        }
    }

    deinit {
        if let observer = subtitleTimeObserver, let player = self.player {
            player.removeTimeObserver(observer)
        }
        itemStatusCancellable?.cancel()
        player?.pause()
        streamingService.playbackEnd()
    }
}
