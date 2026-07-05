//
//  Buttons.swift
//  Stingray
//
//  Created by Ben Roberts on 7/4/26.
//

import AVKit
import UIKit

/// Holds functions for generating A/V player buttons
public final class PlayerButtons {
    /// Advances playback to the given next episode.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - episode: Episode to skip to
    /// - Returns: Formatted button
    public static func nextEpisodeButton(vm: TVPlayerViewModel, nextEpisode episode: any TVEpisodeProtocol) -> UIAction {
        UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.right"), handler: { _ in
            vm.savePlaybackDate()
            vm.mediaSource = episode.mediaSources.first ?? vm.mediaSource
            vm.newPlayer(episode: episode)
        })
    }

    /// Returns playback to the given previous episode.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - episode: Previous episode to load
    /// - Returns: Formatted button
    public static func previousEpisodeButton(vm: TVPlayerViewModel, previousEpisode episode: any TVEpisodeProtocol) -> UIAction {
        UIAction(title: "Previous Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
            vm.savePlaybackDate()
            vm.mediaSource = episode.mediaSources.first ?? vm.mediaSource
            vm.newPlayer(episode: episode)
        })
    }

    /// A menu grouping every season and its episodes for direct selection.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - seasons: All available seasons of the show that also contain episodes
    /// - Returns: Formatted picker
    public static func episodePicker(vm: TVPlayerViewModel, seasons: [any TVSeasonProtocol]) -> UIMenu {
        let seasonItems = seasons.map { season in
            let episodeActions = season.episodes.map { episode in
                let action = UIAction(title: episode.title) { _ in
                    vm.savePlaybackDate()
                    vm.mediaSource = episode.mediaSources.first ?? vm.mediaSource
                    vm.newPlayer(episode: episode)
                }
                action.state = vm.mediaSource.id == episode.mediaSources.first?.id ? .on : .off
                return action
            }

            // Awful limitation by Apple to only support menus one level deep here
            return UIMenu(title: season.title, options: .displayInline, children: episodeActions)
        }
        return UIMenu(
            title: "Seasons",
            image: UIImage(systemName: "calendar.day.timeline.right"),
            children: seasonItems
        )
    }

    /// A menu for choosing the active subtitle stream, including a "None" option.
    /// - Parameter vm: View model containing the playing content
    /// - Returns: Formatted menu
    public static func subtitleStreamPicker(vm: AVPlayerViewModelProtocol) -> UIMenu {
        UIMenu(
            title: "Subtitles",
            image: UIImage(systemName: "captions.bubble"),
            children: [
                {
                    let action = UIAction(title: "None") { _ in
                        vm.newPlayer(
                            startTime: vm.player.currentTime(),
                            videoID: .keep,
                            audioID: .keep,
                            subtitleID: .newID(nil),
                            bitrate: nil
                        )
                    }
                    action.state = vm.playerProgress?.subtitleID == nil ? .on : .off
                    return action
                }()
            ] + vm.mediaSource.subtitleStreams.map { subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    vm
                        .newPlayer(
                            startTime: vm.player.currentTime(),
                            videoID: .keep,
                            audioID: .keep,
                            subtitleID: .newID(subtitleStream.id),
                            bitrate: nil
                        )
                }
                action.state = vm.playerProgress?.subtitleID == subtitleStream.id ? .on : .off
                return action
            }
        )
    }

    /// A menu for choosing the active audio stream.
    /// - Parameter vm: View model containing the playing content
    /// - Returns: Formatted menu
    public static func audioStreamPicker(vm: AVPlayerViewModelProtocol) -> UIMenu {
        UIMenu(
            title: "Audio",
            image: UIImage(systemName: "speaker.wave.2"),
            children: vm.mediaSource.audioStreams.map { audioStream in
                let action = UIAction(title: audioStream.title) { _ in
                    vm
                        .newPlayer(
                            startTime: vm.player.currentTime(),
                            videoID: .keep,
                            audioID: .newID(audioStream.id),
                            subtitleID: .keep,
                            bitrate: nil
                        )
                }
                action.state = vm.playerProgress?.audioID == audioStream.id ? .on : .off
                return action
            }
        )
    }

    /// A menu for choosing the active video stream.
    /// - Parameter vm: View model containing the playing content
    /// - Returns: Formatted menu
    public static func videoStreamPicker(vm: AVPlayerViewModelProtocol) -> UIMenu {
        UIMenu(
            title: "Video",
            image: UIImage(systemName: "display"),
            children: vm.mediaSource.videoStreams.map(
                { videoStream in
                    let action = UIAction(title: videoStream.title) { _ in
                        vm
                            .newPlayer(
                                startTime: vm.player.currentTime(),
                                videoID: .newID(videoStream.id),
                                audioID: .keep,
                                subtitleID: .keep,
                                bitrate: nil
                            )
                    }
                    action.state = vm.playerProgress?.videoID == videoStream.id ? .on : .off
                    return action
                }
            )
        )
    }

    /// A menu for capping the target bitrate of the given video stream.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - videoStream: The currently playing video stream
    /// - Returns: Formatted menu with relevant bitrate options
    public static func bitratePicker(vm: AVPlayerViewModelProtocol, videoStream: any MediaStreamProtocol) -> UIMenu {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        let fullBitrateString = numberFormatter.string(from: NSNumber(value: videoStream.bitrate))
        ?? "\(videoStream.bitrate)"
        let fullBitrate = UIAction(title: "Full - \(fullBitrateString) Bits/sec") { _ in
            vm.newPlayer(startTime: vm.player.currentTime(), videoID: .keep, audioID: .keep, subtitleID: .keep, bitrate: nil)
        }
        fullBitrate.state = {
            if SettingsModel.bitrateOptions.contains(vm.playerProgress?.bitrate ?? -1) {
                return .off
            }
            return .on
        }()
        var bitrateOptions: [UIAction] = [fullBitrate]

        // Helper function to create a bitrate action
        func makeBitrateAction(bitrate: Int) -> UIAction {
            let action = UIAction(title: Int.formatMegabitsPerSec(bitrate)) { _ in
                vm.newPlayer(startTime: vm.player.currentTime(), videoID: .keep, audioID: .keep, subtitleID: .keep, bitrate: bitrate)
            }
            action.state = {
                if vm.playerProgress?.bitrate == bitrate {
                    return .on
                } else {
                    return .off
                }
            }()
            return action
        }

        // Add bitrate options if applicable
        for bitrate in SettingsModel.bitrateOptions where videoStream.bitrate > bitrate {
            bitrateOptions.append(makeBitrateAction(bitrate: bitrate))
        }

        let bitrateIcon: String = {
            if SettingsModel.bitrateOptions.contains(vm.playerProgress?.bitrate ?? -1) {
                return "wifi.badge.lock"
            }
            return "wifi"
        }()

        return UIMenu(
            title: "Target Bitrate",
            image: UIImage(systemName: bitrateIcon),
            children: bitrateOptions
        )
    }

    /// A menu for selecting the playback speed.
    public static func playbackSpeedPicker(vm: AVPlayerViewModelProtocol) -> UIMenu {
        var playbackSpeeds: [UIAction] = []
        for speed in PlaybackSpeed.allCases {
            let action = UIAction(title: speed.name) { _ in
                vm.changeSpeed(speed)
            }
            action.state = vm.player.rate == speed.value ? .on : .off
            playbackSpeeds.append(action)
        }

        return UIMenu(
            title: "Playback Speed",
            image: UIImage(systemName: "gauge.with.dots.needle.33percent"),
            children: playbackSpeeds
        )
    }

    /// Bulk create transport bar items for typical audio & visual players
    /// - Parameter vm: Player's view model
    public static func AVPlayerTransportBarItems(vm: any AVPlayerViewModelProtocol) -> [UIMenuElement] {
        var items: [UIMenuElement] = []

        // Add Subtitles menu only if there are subtitle tracks available
        if !vm.mediaSource.subtitleStreams.isEmpty {
            items.append(PlayerButtons.subtitleStreamPicker(vm: vm))
        }

        // Add Audio menu only if there's more than one option
        if vm.mediaSource.audioStreams.count > 1 {
            items.append(PlayerButtons.audioStreamPicker(vm: vm))
        }

        // Add Video menu only if there's more than one option
        if vm.mediaSource.videoStreams.count > 1 {
            items.append(PlayerButtons.videoStreamPicker(vm: vm))
        }

        // Bitrate choices
        if let videoStream = (vm.mediaSource.videoStreams.first { vm.playerProgress?.videoID == $0.id }),
           videoStream.bitrate > 1_500_000 {
            items.append(PlayerButtons.bitratePicker(vm: vm, videoStream: videoStream))
        }

        // Playback speed picker
        items.append(PlayerButtons.playbackSpeedPicker(vm: vm))

        return items
    }
}
