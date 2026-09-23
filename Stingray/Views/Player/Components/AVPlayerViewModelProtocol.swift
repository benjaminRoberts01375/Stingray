//
//  AVPlayerViewModelProtocol.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVFoundation

/// Basic structure for a view model that a video player to make use of
public protocol AVPlayerViewModelProtocol {
    /// Current player that's rendering content
    var player: AVPlayer { get }
    /// Syncing player progress to the server
    var playerProgress: PlayerProtocol? { get }
    /// Media source that's currently playing
    var mediaSource: any MediaSourceProtocol { get }

    /// Creates a new player based on current state
    /// - Parameters:
    ///   - startTime: Where the video should start from
    ///   - videoID: Video stream identifier. Nil = existing video ID
    ///   - audioID: Audio stream identifier. Nil = existing audio ID
    ///   - subtitleID: Subtitle stream identifier (empty for no subtitles). Nil = existing subtitle ID
    ///   - bitrate: The video's bitrate in bits per second
    func newPlayer(
        startTime: CMTime,
        videoID: StreamTransitionType,
        audioID: StreamTransitionType,
        subtitleID: StreamTransitionType,
        bitrate: Int?
    )

    /// Change the speed of the player
    /// - Parameter speed: Speed to play at
    func changeSpeed(_ speed: PlaybackSpeed)
}
