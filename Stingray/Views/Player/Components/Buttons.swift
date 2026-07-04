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
    public static func nextEpisodeButton(vm: PlayerViewModel, nextEpisode episode: any TVEpisodeProtocol) -> UIAction {
        UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.right"), handler: { _ in
            vm.savePlaybackDate()
            vm.mediaSourceID = episode.mediaSources.first?.id ?? vm.mediaSourceID
            vm.newPlayer(episode: episode)
        })
    }

    /// Returns playback to the given previous episode.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - episode: Previous episode to load
    /// - Returns: Formatted button
    public static func previousEpisodeButton(vm: PlayerViewModel, previousEpisode episode: any TVEpisodeProtocol) -> UIAction {
        UIAction(title: "Previous Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
            vm.savePlaybackDate()
            vm.mediaSourceID = episode.mediaSources.first?.id ?? vm.mediaSourceID
            vm.newPlayer(episode: episode)
        })
    }

    /// A menu grouping every season and its episodes for direct selection.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - seasons: All available seasons of the show that also contain episodes
    /// - Returns: Formatted picker
    public static func episodePicker(vm: PlayerViewModel, seasons: [any TVSeasonProtocol]) -> UIMenu {
        let seasonItems = seasons.map { season in
            let episodeActions = season.episodes.map { episode in
                let action = UIAction(title: episode.title) { _ in
                    vm.savePlaybackDate()
                    vm.mediaSourceID = episode.mediaSources.first?.id ?? vm.mediaSourceID
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
    public static func subtitleStreamPicker(vm: PlayerViewModel) -> UIMenu {
        UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
            {
                let action = UIAction(title: "None") { _ in
                    vm.newPlayer(startTime: vm.player.currentTime(), subtitleID: .newID(nil))
                }
                action.state = vm.playerProgress?.subtitleID == nil ? .on : .off
                return action
            }()
        ] + vm.mediaSource.subtitleStreams.map({ subtitleStream in
            let action = UIAction(title: subtitleStream.title) { _ in
                vm.newPlayer(startTime: vm.player.currentTime(), subtitleID: .newID(subtitleStream.id))
            }
            action.state = vm.playerProgress?.subtitleID == subtitleStream.id ? .on : .off
            return action
        }))
    }

    /// A menu for choosing the active audio stream.
    /// - Parameter vm: View model containing the playing content
    /// - Returns: Formatted menu
   public static func audioStreamPicker(vm: PlayerViewModel) -> UIMenu {
        UIMenu(
            title: "Audio",
            image: UIImage(systemName: "speaker.wave.2"),
            children: vm.mediaSource.audioStreams.map({ audioStream in
                let action = UIAction(title: audioStream.title) { _ in
                    vm.newPlayer(startTime: vm.player.currentTime(), audioID: .newID(audioStream.id))
                }
                action.state = vm.playerProgress?.audioID == audioStream.id ? .on : .off
                return action
            })
        )
    }

    /// A menu for choosing the active video stream.
    /// - Parameter vm: View model containing the playing content
    /// - Returns: Formatted menu
    public static func videoStreamPicker(vm: PlayerViewModel) -> UIMenu {
        UIMenu(
            title: "Video",
            image: UIImage(systemName: "display"),
            children: vm.mediaSource.videoStreams.map({ videoStream in
                let action = UIAction(title: videoStream.title) { _ in
                    vm.newPlayer(startTime: vm.player.currentTime(), videoID: .newID(videoStream.id))
                }
                action.state = vm.playerProgress?.videoID == videoStream.id ? .on : .off
                return action
            })
        )
    }

    /// A menu for capping the target bitrate of the given video stream.
    /// - Parameters:
    ///   - vm: View model containing the playing content
    ///   - videoStream: The currently playing video stream
    /// - Returns: Formatted menu with relevant bitrate options
    public static func bitratePicker(vm: PlayerViewModel, videoStream: any MediaStreamProtocol) -> UIMenu {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal

        let fullBitrateString = numberFormatter.string(from: NSNumber(value: videoStream.bitrate))
        ?? "\(videoStream.bitrate)"
        let fullBitrate = UIAction(title: "Full - \(fullBitrateString) Bits/sec") { _ in
            vm.newPlayer(startTime: vm.player.currentTime(), bitrate: nil)
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
                vm.newPlayer(startTime: vm.player.currentTime(), bitrate: bitrate)
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
    public static func playbackSpeedPicker(vm: PlayerViewModel) -> UIMenu {
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
}
