//
//  SpatialAudioModel.swift
//  Stingray
//
//  Created by kristofferR on 10/11/26.
//

import AVFoundation
import SpatialAudioBridge
import SpatialAudioPlayback

/// Spatial audio playback that can be held and stopped below tvOS 26
public protocol SpatialAudioProtocol: AnyObject {
    /// Stops the stream, its player item, and the Atmos output
    func stop()
}

/// Plays a TrueHD Atmos or DTS:X track as APAC, Apple's spatial audio format, beside the server's video.
///
/// SpatialAudioBridge reads the track from the original file, converts it on demand, and serves it from a loopback HLS server as the only
/// audio of the server's video playlist. `AtmosOutputActivator` keeps the HDMI output in Dolby Atmos while it plays.
@available(tvOS 26, *)
public final class SpatialAudioModel: SpatialAudioProtocol {
    /// Loopback stream serving the converted audio
    private let stream: APACStream
    /// The stream's playlist, with the server's video
    private let playlist: URL
    /// Authenticate the server's video that the playlist references
    private let headers: [String: String]
    /// Keeps the HDMI output in Dolby Atmos
    private let atmos = AtmosOutputActivator()
    /// Player the stream plays through
    private let player: AVPlayer
    /// Where playback starts
    private let startTime: CMTime
    /// Plays the usual audio from the given time
    private let fallback: (CMTime) -> Void
    /// The stream's player item
    private var item: AVPlayerItem?
    /// Watches the item failing to load
    private var statusObservation: NSKeyValueObservation?
    /// Watches the item failing partway through playback
    private var failureObserver: NSObjectProtocol?
    /// Set once stopped, so a failure already on its way can't fall back over a newer session
    private var isStopped = false
    /// Reads files and fetches video playlists over its own connections, so the app's other requests to the server, such as the library
    /// sync at launch, can't hold them up
    private static let session = URLSession(configuration: .default)

    // AI Generated
    /// Wraps a started stream
    /// - Parameters:
    ///   - stream: Loopback stream serving the converted audio
    ///   - playlist: The stream's playlist, with the server's video
    ///   - headers: Authenticate the server's video
    ///   - player: Player to play through
    ///   - startTime: Where playback starts
    ///   - fallback: Plays the usual audio from the given time
    private init(
        stream: APACStream,
        playlist: URL,
        headers: [String: String],
        player: AVPlayer,
        startTime: CMTime,
        fallback: @escaping (CMTime) -> Void
    ) {
        self.stream = stream
        self.playlist = playlist
        self.headers = headers
        self.player = player
        self.startTime = startTime
        self.fallback = fallback
    }

    // AI Generated
    /// The codec SpatialAudioBridge would convert an audio stream with, judging by the server's label
    /// - Parameter audioStream: Audio stream to check
    /// - Returns: The codec for TrueHD Atmos and DTS-HD MA inside the media source's own file, or `nil` for other streams
    public static func codec(of audioStream: any MediaStreamProtocol) -> SpatialAudioCodec? {
        guard !audioStream.isExternal else { return nil }
        switch audioStream.codec {
        case "truehd" where audioStream.profile.contains("Atmos"): return .trueHDAtmos
        // The server doesn't label every DTS:X track, so probe every DTS-HD MA track
        case "dts" where audioStream.profile.hasPrefix("DTS-HD MA"): return .dtsX
        default: return nil
        }
    }

    // AI Generated
    /// Starts converting an audio stream, without touching the player yet. Gives up after 25 seconds, as a busy server can be slow.
    /// - Parameters:
    ///   - content: The server's file, video playlist, and headers
    ///   - audioStream: Audio stream to convert
    ///   - mediaSource: Media source the audio stream belongs to
    ///   - startTime: Where playback will start, which is converted first
    ///   - player: Player to play through
    ///   - fallback: Plays the usual audio from the given time, if the stream fails during playback
    /// - Returns: A stream ready to play
    /// - Throws: `SpatialAudioError.unsupported` for a track SpatialAudioBridge will never play, or any other error for a failure that may
    ///   pass
    public static func start(
        content: SpatialAudioContent,
        audioStream: any MediaStreamProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime,
        player: AVPlayer,
        fallback: @escaping (CMTime) -> Void
    ) async throws -> SpatialAudioModel {
        let starting = Task {
            try await Self.open(
                content: content,
                audioStream: audioStream,
                mediaSource: mediaSource,
                startTime: startTime,
                player: player,
                fallback: fallback
            )
        }
        let deadline = Task {
            try await Task.sleep(for: .seconds(25))
            Log.warning("Spatial audio took too long to start")
            starting.cancel()
        }
        defer { deadline.cancel() }
        return try await withTaskCancellationHandler { try await starting.value } onCancel: { starting.cancel() }
    }

    // AI Generated
    /// Opens the server's file and starts converting an audio stream. See `start`.
    private static func open(
        content: SpatialAudioContent,
        audioStream: any MediaStreamProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime,
        player: AVPlayer,
        fallback: @escaping (CMTime) -> Void
    ) async throws -> SpatialAudioModel {
        let started = ContinuousClock.now
        try AtmosOutputActivator.configureAudioSession()
        let file = try await MatroskaFile.open(HTTPByteSource(url: content.file, headers: content.headers, session: Self.session))

        // The server numbers streams its own way, but lists the file's audio tracks in the file's order
        let audioStreams = mediaSource.audioStreams.filter { !$0.isExternal }
        guard let codec = Self.codec(of: audioStream),
              let index = audioStreams.firstIndex(where: { $0.id == audioStream.id }),
              file.audioTracks.indices.contains(index),
              file.audioTracks[index].codec == codec
        else { throw SpatialAudioError.source("The file's audio tracks don't match the server's") }
        let track = file.audioTracks[index]

        // Telling DTS:X from plain DTS-HD MA takes decoding, which a probe does without starting the encoder
        if codec == .dtsX, case .unsupported(let reason) = try await file.probe(track, from: startTime) {
            throw SpatialAudioError.unsupported(reason)
        }
        try Task.checkCancellation()

        var options = APACStream.Options()
        options.session = Self.session
        // Only the stream copy: AVPlayer switches to the server's SDR transcodes when a segment is slow
        options.includesVideoVariant = { $0.query?.range(of: "allowVideoStreamCopy=false", options: .caseInsensitive) == nil }
        let stream = try await APACStream.start(
            file: file,
            track: track,
            videoMaster: content.videoPlaylist,
            videoHeaders: content.headers,
            startTime: startTime,
            options: options
        )
        guard !Task.isCancelled, let playlist = stream.masterPlaylistURL else { // The playlist is set whenever a video playlist was given
            await stream.stop()
            throw CancellationError()
        }
        let elapsed = (ContinuousClock.now - started).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))
        Log.info("Playing \(track.codecID) track \(track.number) through SpatialAudioBridge, which started in \(elapsed)")
        return SpatialAudioModel(
            stream: stream,
            playlist: playlist,
            headers: content.headers,
            player: player,
            startTime: startTime,
            fallback: fallback
        )
    }

    // AI Generated
    /// Puts the stream's item in the player at the start time. The player keeps the rate the caller set, or a pause.
    /// - Parameters:
    ///   - title: Main title of the content to be shown
    ///   - subtitle: An optional descriptor of the content (ex. season 2, episode 4)
    public func play(title: String, subtitle: String?) {
        // Authenticate like the usual player item, so no URL carries the access token
        let item = AVPlayerItem(asset: AVURLAsset(url: self.playlist, options: ["AVURLAssetHTTPHeaderFieldsKey": self.headers]))
        item.setTitle(title, subtitle: subtitle)
        item.audioTimePitchAlgorithm = .spectral
        self.statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed { self?.fail(item.error) }
        }
        self.failureObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] notification in
            self?.fail(notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)
        }
        self.item = item

        self.atmos.attach(to: self.player) // The playlist offers only APAC audio, so every item plays it
        self.player.replaceCurrentItem(with: item)
        self.player.seek(to: self.startTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // AI Generated
    /// Plays the usual audio instead, from where playback was, once the stream has failed
    /// - Parameter error: Why the item failed, if known
    private func fail(_ error: Error?) {
        guard !self.isStopped else { return }
        Task { [stream] in
            // The stream knows why it ended, such as a decoding failure, which the item reports only as a failed segment
            let reason = await stream.failure ?? error
            Log.warning("Spatial audio failed, so playing the usual audio: \(reason.map { String(describing: $0) } ?? "Unknown error")")
        }
        let current = self.player.currentTime() // Zero until the first seek lands
        self.fallback(current.isNumeric && current > .zero ? current : self.startTime)
    }

    // AI Generated
    /// Stops the stream, its player item, and the Atmos output
    public func stop() {
        self.isStopped = true
        self.statusObservation = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        // Leave the player alone if it has moved on to another item
        if self.player.currentItem === self.item { self.player.replaceCurrentItem(with: nil) }
        self.atmos.detach()
        Task { [stream] in await stream.stop() }
    }
}
