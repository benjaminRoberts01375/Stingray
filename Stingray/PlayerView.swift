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
        .task { self.vm.newPlayer(startTime: self.vm.startTime) }
        .ignoresSafeArea(.all)
        .onDisappear { vm.streamingService.playbackEnd() }
    }
    
    private func makeTransportBarItems() -> [UIMenuElement] {
        // Typical buttons
        var items: [UIMenuElement] = []
        
        // Add Subtitles menu only if there are subtitle tracks available
        if !self.vm.mediaSource.subtitleStreams.isEmpty {
            items.append(UIMenu(title: "Subtitles", image: UIImage(systemName: "captions.bubble"), children: [
                {
                    let action = UIAction(title: "None") { _ in
                        self.vm.selectedSubtitleID = nil
                        self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                        
                    }
                    action.state = self.vm.selectedSubtitleID == nil ? .on : .off
                    return action
                }()
            ] + self.vm.mediaSource.subtitleStreams.map({ subtitleStream in
                let action = UIAction(title: subtitleStream.title) { _ in
                    self.vm.selectedSubtitleID = subtitleStream.id
                    self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                }
                action.state = self.vm.selectedSubtitleID == subtitleStream.id ? .on : .off
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
                            self.vm.selectedAudioID = audioStream.id
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                        }
                        action.state = self.vm.selectedAudioID == audioStream.id ? .on : .off
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
                            self.vm.selectedVideoID = videoStream.id
                            self.vm.newPlayer(startTime: self.vm.player?.currentTime() ?? .zero)
                        }
                        action.state = self.vm.selectedVideoID == videoStream.id ? .on : .off
                        return action
                    })
                )
            )
        }
        
        // TV Season-related buttons
        if let seasons = self.vm.seasons {
            let allEpisodes = seasons.flatMap(\.episodes)
            var setPreviousEpisode: Bool = false
            
            if let index = allEpisodes.firstIndex(where: { episode in
                for mediaSource in episode.mediaSources where mediaSource.id != self.vm.mediaSource.id {
                    return true
                }
                return false
            }) {
                // Next episode
                if index + 1 < allEpisodes.count {
                    let episode = allEpisodes[index + 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.right"), handler: { _ in
                        self.vm.newIDsFromPreviousMedia(episode: episode)
                        self.vm.mediaSource = episode.mediaSources.first ?? self.vm.mediaSource
                        self.vm.newIDsFromPreviousMedia(episode: episode)
                        self.vm.newPlayer(startTime: .zero)
                    }), at: 0)
                }
                
                // Previous episode
                if index - 1 >= 0 {
                    let episode = allEpisodes[index - 1]
                    items.insert(UIAction(title: "Next Episode", image: UIImage(systemName: "arrow.left"), handler: { _ in
                        self.vm.newIDsFromPreviousMedia(episode: episode)
                        self.vm.newPlayer(startTime: .zero)
                    }), at: 0)
                    setPreviousEpisode = true
                }
            }
            
            // Episode selector
            let seasonItems = seasons.map { season in
                let episodeActions = season.episodes.map { episode in
                    let action = UIAction(title: episode.title) { _ in
                        self.vm.newIDsFromPreviousMedia(episode: episode)
                        self.vm.newPlayer(startTime: .zero)
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
        controller.allowsPictureInPicturePlayback = true
        controller.allowedSubtitleOptionLanguages = .init(["nerd"])
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.transportBarCustomMenuItems = transportBarCustomMenuItems
    }
}
