//
//  PlayerView.swift
//  Stingray
//
//  Created by Ben Roberts on 11/19/25.
//

import AVKit
import SwiftUI

struct PlayerView: View {
    @State var vm: PlayerViewModel
    
    init(vm: PlayerViewModel) { self.vm = vm }
    
    var body: some View {
        VStack {
            if let player = self.vm.player {
                AVPlayerViewControllerRepresentable(
                    player: player,
                    transportBarCustomMenuItems: makeTransportBarItems()
                )
            }
        }
        .onAppear {
            // Only run if player hasn't been set up yet
            guard self.vm.player == nil else { return }
            
            let userModel = UserModel()
            var subtitleID: String?
            if let defaultUser = userModel.getDefaultUser() {
                if defaultUser.usesSubtitles {
                    subtitleID = self.vm.mediaSource.subtitleStreams.first {
                        $0.isDefault
                    }?.id ?? self.vm.mediaSource.subtitleStreams.first?.id
                }
                if let bitrate = defaultUser.bitrate {
                    if let bitrate = defaultUser.bitrate { self.vm.bitrate = .limited(bitrate) }
                    else { self.vm.bitrate = .full }
                }
            }
            self.vm.newPlayer(
                startTime: self.vm.startTime,
                videoID: self.vm.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.vm.mediaSource.videoStreams.first?.id ?? "0"),
                audioID: self.vm.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.vm.mediaSource.audioStreams.first?.id ?? "1"),
                subtitleID: subtitleID
            )
        }
        .ignoresSafeArea(.all)
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        // Typical buttons
        var items: [UIMenuElement] = []
        
        // Add Subtitles menu only if there are subtitle tracks available
        if !self.vm.mediaSource.subtitleStreams.isEmpty {
            items.append(UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                    }
                    action.state = self.vm.playerProgress?.subtitleID == nil ? .on : .off
                    return action
                }()
            ] + self.vm.mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, subtitleID: subtitleStream.id)
                }
                action.state = self.vm.playerProgress?.subtitleID == subtitleStream.id ? .on : .off
                return action
            })))
        }
        
        // Add Audio menu only if there's more than one option
        if self.vm.mediaSource.audioStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Audio",
                    image: UIImage(systemName: "speaker.wave.2"),
                    children: self.vm.mediaSource.audioStreams.map({ audioStream in
                        let action = UIAction(title: audioStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, audioID: audioStream.id)
                        }
                        action.state = self.vm.playerProgress?.audioID == audioStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // Add Video menu only if there's more than one option
        if self.vm.mediaSource.videoStreams.count > 1 {
            items.append(
                UIMenu(
                    title: "Video",
                    image: UIImage(systemName: "display"),
                    children: self.vm.mediaSource.videoStreams.map({ videoStream in
                        let action = UIAction(title: videoStream.title) { _ in
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero, videoID: videoStream.id)
                        }
                        action.state = self.vm.playerProgress?.videoID == videoStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // Bitrate choices
        if let videoStream = (self.vm.mediaSource.videoStreams.first { self.vm.playerProgress?.videoID == $0.id }),
           videoStream.bitrate > 1_500_000 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            
            let fullBitrateString = numberFormatter.string(from: NSNumber(value: videoStream.bitrate))
                ?? "\(videoStream.bitrate)"
            let fullBitrate = UIAction(title: "Full - \(fullBitrateString) Bits/sec") { _ in
                self.vm.bitrate = .full
                self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
            }
            fullBitrate.state = {
                if case .full = self.vm.bitrate {
                    return .on
                } else {
                    return .off
                }
            }()
            var bitrateOptions: [UIAction] = [fullBitrate]
            
            // Helper function to create a bitrate action
            func makeBitrateAction(bitrate: Int) -> UIAction {
                let mbps = Double(bitrate) / 1_000_000
                let title = mbps.truncatingRemainder(dividingBy: 1) == 0 
                    ? "\(Int(mbps)) Mbps" 
                    : "\(mbps) Mbps"
                
                let action = UIAction(title: title) { _ in
                    self.vm.bitrate = .limited(bitrate)
                    self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                }
                action.state = {
                    if case .limited(let limit) = self.vm.bitrate, limit == bitrate {
                        return .on
                    } else {
                        return .off
                    }
                }()
                return action
            }
            
            // Add common bitrate options if applicable
            let commonBitrates = stride(from: 20_000_000, to: videoStream.bitrate, by: 10_000_000).reversed() +
            [15_000_000, 10_000_000, 5_000_000, 1_500_000, 500_000]
            for bitrate in commonBitrates where videoStream.bitrate > bitrate {
                bitrateOptions.append(makeBitrateAction(bitrate: bitrate))
            }
            
            let bitrateIcon: String = {
                if case .full = self.vm.bitrate {
                    return "wifi"
                } else {
                    return "wifi.badge.lock"
                }
            }()
            
            items.append(
                UIMenu(
                    title: "Target Bitrate",
                    image: UIImage(systemName: bitrateIcon),
                    children: bitrateOptions
                )
            )
        }
        
        // TV Season-related buttons
        if let seasons = self.vm.seasons {
            let allEpisodes = seasons.flatMap(\.episodes)
            var setPreviousEpisode: Bool = false
            
            if let index = allEpisodes.firstIndex(where: { episode in
                for mediaSource in episode.mediaSources {
                    return mediaSource.id == self.vm.mediaSource.id
                }
                return false
            }) {
                // Next episode
                if index + 1 < allEpisodes.count {
                    let episode = allEpisodes[index + 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.right"), handler: { _ in
                        self.vm.mediaSource = episode.mediaSources.first ?? self.vm.mediaSource
                        self.vm.newPlayer(episode: episode)
                    }), at: 0)
                }
                
                // Previous episode
                if index - 1 >= 0 {
                    let episode = allEpisodes[index - 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
                        self.vm.mediaSource = episode.mediaSources.first ?? self.vm.mediaSource
                        self.vm.newPlayer(episode: episode)
                    }), at: 0)
                    setPreviousEpisode = true
                }
            }
            
            // Episode selector
            let seasonItems = seasons.map { season in
                let episodeActions = season.episodes.map { episode in
                    let action = UIAction(title: episode.title) { _ in
                        self.vm.mediaSource = episode.mediaSources.first ?? self.vm.mediaSource
                        self.vm.newPlayer(episode: episode)
                    }
                    action.state = self.vm.mediaSource.id == episode.mediaSources.first?.id ? .on : .off
                    return action
                }
                
                // Awful limitation by Apple to only support menus one level deep here
                return UIMenu(title: season.title, options: .displayInline, children: episodeActions)
            }
            items.insert(
                UIMenu(
                    title: "Seasons",
                    image: UIImage(systemName: "calendar.day.timeline.right"),
                    children: seasonItems
                ), at: setPreviousEpisode ? 1 : 0
            )
        }
        return items
    }
}

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let transportBarCustomMenuItems: [UIMenuElement]
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.transportBarCustomMenuItems = transportBarCustomMenuItems
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = false
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.transportBarCustomMenuItems = transportBarCustomMenuItems
    }
}
